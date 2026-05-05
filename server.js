const express = require("express");
const jwt = require("jsonwebtoken");
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const os = require("os");

const app = express();
app.use(express.json());

const JWT_SECRET = "arms-demo-secret-key-2026";
const PORT = 3000;
const HOST = "10.8.0.1";

const EASY_RSA_DIR = path.join(os.homedir(), "easy-rsa");
const PKI_DIR = path.join(EASY_RSA_DIR, "pki");

// ── VPN identity-guard configuration ──────────────────────────
// CCD directory: per-cert OpenVPN policy files live here.
// Sessions file: written by the OpenVPN client-connect/disconnect
// hooks; one line per active tunnel, formatted "<tunnel-ip> <CN>".
const CCD_DIR = "/etc/openvpn/ccd";
const SESSIONS_FILE = "/var/run/openvpn/sessions";

// CRL: certificate revocation list consumed by OpenVPN's `crl-verify`.
// We generate it via easy-rsa locally (PKI_CRL_PATH) and install a
// readable copy at OPENVPN_CRL_PATH, which is what server.conf points to.
const PKI_CRL_PATH = path.join(PKI_DIR, "crl.pem");
const OPENVPN_CRL_PATH = "/etc/openvpn/crl.pem";

// Admin token for protected revocation endpoints. Set via env var in
// production; never bake this into source. The fallback is for the demo.
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || "arms-demo-admin-token-2026";

// Email addresses that get the isAdmin claim in their JWT after login.
// In production this would come from EntraID group membership.
const ADMIN_EMAILS = new Set(["maxwell.ehiawey@amalitech.com"]);

// OpenVPN management socket (optional). When configured in server.conf,
// we can use it to kick a revoked user's active tunnel immediately
// instead of waiting for them to reconnect.
const OPENVPN_MGMT_SOCKET =
  process.env.OPENVPN_MGMT_SOCKET || "/var/run/openvpn/mgmt.sock";

// CN of the bootstrap cert bundled inside the Flutter APK.
// Re-issue this cert on the EC2 if your existing bundled cert has a
// different CN, OR change this constant to match what's already there.
const DEFAULT_BOOTSTRAP_CN = "client1.domain.tld";

// Endpoints the client1 tunnel is allowed to hit. Anything else
// from a default-bootstrap tunnel returns 403 — even if the caller
// somehow has a valid JWT.
const BOOTSTRAP_ALLOWED_PATHS = new Set([
  "/api/health",
  "/api/auth/login",
  "/api/vpn/config",
]);

// ── Fetch server public IP once at startup ────────────────────
let SERVER_PUBLIC_IP = process.env.PUBLIC_IP || "";
if (!SERVER_PUBLIC_IP) {
  try {
    SERVER_PUBLIC_IP = execSync("curl -s --max-time 5 ifconfig.me", {
      encoding: "utf8",
    }).trim();
    console.log(`Public IP resolved: ${SERVER_PUBLIC_IP}`);
  } catch (e) {
    console.warn("WARNING: Could not fetch public IP — set PUBLIC_IP env var");
  }
}

// ── Read CA cert once at startup (shared across all configs) ──
let CA_CERT = "";
const caCertPath = path.join(PKI_DIR, "ca.crt");
if (fs.existsSync(caCertPath)) {
  CA_CERT = fs.readFileSync(caCertPath, "utf8").trim();
  console.log("CA cert loaded from", caCertPath);
} else {
  console.warn("WARNING: CA cert not found at", caCertPath);
}

// ── Demo employee data ────────────────────────────────────────
// Simulates what would come from Microsoft EntraID / company directory.
const DEMO_USERS = {
  "gideon.dakore@amalitech.com": {
    password: "Password@123",
    name: "Gideon Dakore",
    department: "Software Engineering",
    position: "Software Engineer",
    employeeId: "AMT-2024-001",
    joinDate: "2024-01-15",
    leaveBalance: {
      annual: { total: 21, used: 8 },
      sick: { total: 10, used: 2 },
      emergency: { total: 3, used: 0 },
    },
    clocking: {
      clockIn: "08:47 AM",
      clockInIso: "2026-05-01T08:47:00",
      status: "clocked_in",
      location: "Amalitech Office — Kumasi",
    },
    recentLeaves: [
      {
        id: 1,
        type: "Annual Leave",
        from: "2026-04-14",
        to: "2026-04-18",
        days: 5,
        status: "approved",
      },
      {
        id: 2,
        type: "Sick Leave",
        from: "2026-03-03",
        to: "2026-03-03",
        days: 1,
        status: "approved",
      },
      {
        id: 3,
        type: "Annual Leave",
        from: "2026-05-26",
        to: "2026-05-30",
        days: 5,
        status: "pending",
      },
    ],
  },
  "maxwell.ehiawey@amalitech.com": {
    password: "Password@123",
    name: "Maxwell Ehiawey",
    department: "Product Owner",
    position: "DevOps Engineer",
    employeeId: "AMT-2023-045",
    joinDate: "2023-06-01",
    leaveBalance: {
      annual: { total: 21, used: 14 },
      sick: { total: 10, used: 5 },
      emergency: { total: 3, used: 1 },
    },
    clocking: {
      clockIn: "09:02 AM",
      clockInIso: "2026-05-01T09:02:00",
      status: "clocked_in",
      location: "Amalitech Office - Accra",
    },
    recentLeaves: [
      {
        id: 4,
        type: "Annual Leave",
        from: "2026-03-24",
        to: "2026-03-28",
        days: 5,
        status: "approved",
      },
      {
        id: 5,
        type: "Emergency Leave",
        from: "2026-02-10",
        to: "2026-02-10",
        days: 1,
        status: "approved",
      },
    ],
  },
  "bernard.wodoame@amalitech.com": {
    password: "Password@123",
    name: "Bernard Mawulorm Kofi Wodoame",
    department: "Backend Engineer",
    position: "Product Manager",
    employeeId: "AMT-2022-012",
    joinDate: "2022-03-20",
    leaveBalance: {
      annual: { total: 21, used: 3 },
      sick: { total: 10, used: 0 },
      emergency: { total: 3, used: 0 },
    },
    clocking: {
      clockIn: "08:45 AM",
      clockInIso: "2026-05-01T08:45:00",
      status: "clocked_in",
      location: "Amalitech Office - Accra",
    },
    recentLeaves: [
      {
        id: 6,
        type: "Annual Leave",
        from: "2026-01-20",
        to: "2026-01-22",
        days: 3,
        status: "approved",
      },
    ],
  },
  "nawas.hutchful@amalitech.com": {
    password: "Password@123",
    name: "Nawas Hutchful",
    department: "Design",
    position: "UI/UX Designer",
    employeeId: "AMT-2023-078",
    joinDate: "2023-09-11",
    leaveBalance: {
      annual: { total: 21, used: 5 },
      sick: { total: 10, used: 1 },
      emergency: { total: 3, used: 0 },
    },
    clocking: {
      clockIn: "08:55 AM",
      clockInIso: "2026-05-01T08:55:00",
      status: "clocked_in",
      location: "Amalitech Office - Accra",
    },
    recentLeaves: [
      {
        id: 7,
        type: "Annual Leave",
        from: "2026-02-16",
        to: "2026-02-20",
        days: 5,
        status: "approved",
      },
      {
        id: 8,
        type: "Sick Leave",
        from: "2026-04-07",
        to: "2026-04-07",
        days: 1,
        status: "approved",
      },
    ],
  },
  "samuel.abayizera@amalitech.com": {
    password: "Password@123",
    name: "Abayizera Samuel",
    department: "Software Engineering",
    position: "Junior Associate Software Engineer",
    employeeId: "AMT-2024-032",
    joinDate: "2024-03-04",
    leaveBalance: {
      annual: { total: 21, used: 2 },
      sick: { total: 10, used: 0 },
      emergency: { total: 3, used: 0 },
    },
    clocking: {
      clockIn: "09:10 AM",
      clockInIso: "2026-05-01T09:10:00",
      status: "clocked_in",
      location: "Amalitech Office - Kigali",
    },
    recentLeaves: [
      {
        id: 9,
        type: "Annual Leave",
        from: "2026-03-10",
        to: "2026-03-11",
        days: 2,
        status: "approved",
      },
    ],
  },
  "caleb.gisa@amalitech.com": {
    password: "Password@123",
    name: "Caleb Gisa",
    department: "Mobile Development",
    position: "Mobile App Developer",
    employeeId: "AMT-2023-061",
    joinDate: "2023-07-17",
    leaveBalance: {
      annual: { total: 21, used: 7 },
      sick: { total: 10, used: 3 },
      emergency: { total: 3, used: 1 },
    },
    clocking: {
      clockIn: "08:30 AM",
      clockInIso: "2026-05-01T08:30:00",
      status: "clocked_in",
      location: "Amalitech Office - Kigali",
    },
    recentLeaves: [
      {
        id: 10,
        type: "Annual Leave",
        from: "2026-01-06",
        to: "2026-01-10",
        days: 5,
        status: "approved",
      },
      {
        id: 11,
        type: "Emergency Leave",
        from: "2026-03-19",
        to: "2026-03-19",
        days: 1,
        status: "approved",
      },
    ],
  },
  "emmanuel.ansu@amalitech.com": {
    password: "Password@123",
    name: "Emmanuel Kwabena Ansu",
    department: "Cyber Security",
    position: "Cyber Security Analyst",
    employeeId: "AMT-2023-054",
    joinDate: "2023-05-22",
    leaveBalance: {
      annual: { total: 21, used: 10 },
      sick: { total: 10, used: 4 },
      emergency: { total: 3, used: 0 },
    },
    clocking: {
      clockIn: "08:50 AM",
      clockInIso: "2026-05-01T08:50:00",
      status: "clocked_in",
      location: "Amalitech Office - Accra",
    },
    recentLeaves: [
      {
        id: 12,
        type: "Annual Leave",
        from: "2026-02-02",
        to: "2026-02-06",
        days: 5,
        status: "approved",
      },
      {
        id: 13,
        type: "Sick Leave",
        from: "2026-04-21",
        to: "2026-04-23",
        days: 3,
        status: "approved",
      },
    ],
  },
  "franz-james.kaba@amalitech.com": {
    password: "Password@123",
    name: "Franz-James Kaba",
    department: "Quality Assurance",
    position: "Quality Assurance Engineer",
    employeeId: "AMT-2022-089",
    joinDate: "2022-08-08",
    leaveBalance: {
      annual: { total: 21, used: 12 },
      sick: { total: 10, used: 2 },
      emergency: { total: 3, used: 1 },
    },
    clocking: {
      clockIn: "09:00 AM",
      clockInIso: "2026-05-01T09:00:00",
      status: "clocked_in",
      location: "Amalitech Office - Takoradi",
    },
    recentLeaves: [
      {
        id: 14,
        type: "Annual Leave",
        from: "2026-03-30",
        to: "2026-04-03",
        days: 5,
        status: "approved",
      },
      {
        id: 15,
        type: "Emergency Leave",
        from: "2026-01-15",
        to: "2026-01-15",
        days: 1,
        status: "approved",
      },
    ],
  },
  "ernest.essien@amalitech.com": {
    password: "Password@123",
    name: "Ernest Kojo Owusu Essien",
    department: "Backend Engineering",
    position: "Backend Engineer",
    employeeId: "AMT-2023-037",
    joinDate: "2023-02-13",
    leaveBalance: {
      annual: { total: 21, used: 6 },
      sick: { total: 10, used: 1 },
      emergency: { total: 3, used: 0 },
    },
    clocking: {
      clockIn: "08:40 AM",
      clockInIso: "2026-05-01T08:40:00",
      status: "clocked_in",
      location: "Amalitech Office - Takoradi",
    },
    recentLeaves: [
      {
        id: 16,
        type: "Annual Leave",
        from: "2026-04-07",
        to: "2026-04-11",
        days: 5,
        status: "approved",
      },
      {
        id: 17,
        type: "Sick Leave",
        from: "2026-02-25",
        to: "2026-02-25",
        days: 1,
        status: "approved",
      },
    ],
  },
};

// ── Certificate helpers ───────────────────────────────────────

// Extract only the PEM block from a .crt file (easy-rsa includes extra text).
function extractPem(raw) {
  const match = raw.match(
    /-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/,
  );
  return match ? match[0].trim() : raw.trim();
}

// Generate a client cert+key pair via easy-rsa (if missing) AND write
// the matching CCD policy file (if missing). With ccd-exclusive enabled
// on the OpenVPN server, the CCD file is required for the cert to be
// allowed to connect at all.
function ensureClientCert(username) {
  const certPath = path.join(PKI_DIR, "issued", `${username}.crt`);
  const keyPath = path.join(PKI_DIR, "private", `${username}.key`);
  const ccdPath = path.join(CCD_DIR, username);

  // 1. Generate cert/key if missing.
  if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
    console.log(`[CERT] Reusing existing cert for ${username}`);
  } else {
    console.log(`[CERT] Generating new certificate for ${username}...`);
    execSync(`./easyrsa build-client-full ${username} nopass`, {
      cwd: EASY_RSA_DIR,
      encoding: "utf8",
      timeout: 60_000,
      env: {
        ...process.env,
        EASYRSA_BATCH: "1", // suppress interactive prompts
      },
    });
    console.log(`[CERT] Certificate ready for ${username}`);
  }

  // 2. Write per-user CCD policy if missing. Personalized users get
  // the full VPN subnet pushed; the default-bootstrap CCD is created
  // once by hand on the EC2 (see deployment guide).
  if (fs.existsSync(CCD_DIR) && !fs.existsSync(ccdPath)) {
    try {
      fs.writeFileSync(
        ccdPath,
        `# Auto-generated for ${username} on ${new Date().toISOString()}\n` +
          `push "route 10.8.0.0 255.255.255.0"\n`,
        { mode: 0o644 },
      );
      console.log(`[CCD] Wrote per-user policy for ${username}`);
    } catch (e) {
      console.warn(
        `[CCD] Could not write CCD file (${ccdPath}): ${e.message}. ` +
          `Make sure the Node process can write to ${CCD_DIR}.`,
      );
    }
  }
}

// ── Revocation ────────────────────────────────────────────────
//
// Revocation flow:
//   1. easyrsa revoke <username>   — marks the cert as revoked
//   2. easyrsa gen-crl             — regenerates pki/crl.pem
//   3. Copy crl.pem to OPENVPN_CRL_PATH so OpenVPN re-reads it
//   4. Delete the user's CCD file  — defense in depth: even if the
//      CRL hasn't been refreshed yet, ccd-exclusive blocks reconnects
//   5. (Optional) Kick the active tunnel via OpenVPN management socket
//
// OpenVPN re-reads the CRL on every new TLS handshake; existing
// tunnels are unaffected unless we explicitly kill them.

function regenerateCRL() {
  console.log(`[CRL] Regenerating CRL via easyrsa…`);
  execSync(`./easyrsa gen-crl`, {
    cwd: EASY_RSA_DIR,
    encoding: "utf8",
    timeout: 30_000,
    env: { ...process.env, EASYRSA_BATCH: "1" },
  });

  if (!fs.existsSync(PKI_CRL_PATH)) {
    throw new Error(`Expected CRL at ${PKI_CRL_PATH} after gen-crl`);
  }

  // Atomically replace the destination via temp-file + rename.
  // This works even if the existing CRL is owned by root, as long as
  // we have write permission on the parent directory (/etc/openvpn).
  // copyFileSync would fail with EACCES because it tries to open the
  // existing root-owned file for writing.
  const tmpPath = `${OPENVPN_CRL_PATH}.${Date.now()}.tmp`;
  try {
    fs.copyFileSync(PKI_CRL_PATH, tmpPath);
    fs.chmodSync(tmpPath, 0o644);
    fs.renameSync(tmpPath, OPENVPN_CRL_PATH);
  } catch (e) {
    // Best-effort cleanup of the temp file if anything failed.
    try {
      fs.unlinkSync(tmpPath);
    } catch {}
    throw e;
  }

  console.log(`[CRL] Installed updated CRL at ${OPENVPN_CRL_PATH}`);
}

function killActiveTunnel(username) {
  // Best-effort kick of an active tunnel via OpenVPN's management socket.
  // Silently no-ops if the socket isn't available.
  if (!fs.existsSync(OPENVPN_MGMT_SOCKET)) {
    console.log(
      `[REVOKE] Management socket not available (${OPENVPN_MGMT_SOCKET}); skip kick`,
    );
    return;
  }
  try {
    execSync(
      `printf 'kill ${username}\\nquit\\n' | nc -q1 -U ${OPENVPN_MGMT_SOCKET}`,
      { encoding: "utf8", timeout: 5_000, shell: "/bin/bash" },
    );
    console.log(`[REVOKE] Kicked active tunnel for ${username}`);
  } catch (e) {
    console.warn(`[REVOKE] Could not kick active tunnel: ${e.message}`);
  }
}

function revokeUser(username) {
  const certPath = path.join(PKI_DIR, "issued", `${username}.crt`);
  if (!fs.existsSync(certPath)) {
    throw new Error(`No certificate found for ${username}`);
  }

  console.log(`[REVOKE] Revoking certificate for ${username}…`);
  execSync(`./easyrsa revoke ${username}`, {
    cwd: EASY_RSA_DIR,
    encoding: "utf8",
    timeout: 30_000,
    env: { ...process.env, EASYRSA_BATCH: "1" },
  });

  regenerateCRL();

  // Delete the CCD file so a stale CRL doesn't let them reconnect
  // (ccd-exclusive will refuse the connection without a CCD file).
  const ccdPath = path.join(CCD_DIR, username);
  if (fs.existsSync(ccdPath)) {
    fs.unlinkSync(ccdPath);
    console.log(`[REVOKE] Removed CCD file for ${username}`);
  }

  killActiveTunnel(username);

  console.log(`[REVOKE] ${username} fully revoked`);
}

// ── Admin auth ────────────────────────────────────────────────
//
// Two ways to authenticate as admin:
//   1. X-Admin-Token header — for curl, cron, deploys.
//   2. Bearer JWT whose payload has isAdmin: true — for the Flutter app
//      logged in as an admin user.
function requireAdmin(req, res, next) {
  const adminToken = req.headers["x-admin-token"];
  if (adminToken && adminToken === ADMIN_TOKEN) {
    return next();
  }

  const authHeader = req.headers["authorization"];
  if (authHeader && authHeader.startsWith("Bearer ")) {
    try {
      const decoded = jwt.verify(authHeader.split(" ")[1], JWT_SECRET);
      if (decoded.isAdmin) {
        req.user = decoded;
        return next();
      }
    } catch {
      /* fall through to 403 */
    }
  }

  return res.status(403).json({ error: "Admin access required" });
}

// Assemble the personalized .ovpn content with embedded certs.
function buildOvpnConfig(username, name, employeeId) {
  const certPath = path.join(PKI_DIR, "issued", `${username}.crt`);
  const keyPath = path.join(PKI_DIR, "private", `${username}.key`);

  const cert = extractPem(fs.readFileSync(certPath, "utf8"));
  const key = fs.readFileSync(keyPath, "utf8").trim();

  return [
    `# ============================================================`,
    `# ARMS Mobile — Personalized VPN config`,
    `# Employee : ${name}`,
    `# Username : ${username}`,
    `# ID       : ${employeeId}`,
    `# Generated: ${new Date().toISOString()}`,
    `# ============================================================`,
    ``,
    `client`,
    `dev tun`,
    `proto udp`,
    `remote ${SERVER_PUBLIC_IP} 1194`,
    `resolv-retry infinite`,
    `nobind`,
    `persist-key`,
    `persist-tun`,
    `remote-cert-tls server`,
    `cipher AES-256-GCM`,
    `verb 3`,
    ``,
    `setenv UV_USERNAME ${username}`,
    `setenv UV_EMPLOYEE_ID ${employeeId}`,
    ``,
    `<ca>`,
    CA_CERT,
    `</ca>`,
    ``,
    `<cert>`,
    cert,
    `</cert>`,
    ``,
    `<key>`,
    key,
    `</key>`,
  ].join("\n");
}

// ── VPN identity guard ────────────────────────────────────────
//
// OpenVPN's client-connect hook writes "<tunnel-ip> <CN>" lines to
// SESSIONS_FILE on every connect and removes them on disconnect.
// Reading that file lets us know which cert each request came from
// even though all tunnels look identical at the TCP level.

function readSessionMap() {
  if (!fs.existsSync(SESSIONS_FILE)) return {};
  try {
    const content = fs.readFileSync(SESSIONS_FILE, "utf8").trim();
    if (!content) return {};
    const map = {};
    for (const line of content.split("\n")) {
      const [ip, cn] = line.trim().split(/\s+/);
      if (ip && cn) map[ip] = cn;
    }
    return map;
  } catch (e) {
    console.warn(`[GUARD] Could not read ${SESSIONS_FILE}: ${e.message}`);
    return {};
  }
}

function commonNameForRequest(req) {
  // Strip IPv4-mapped IPv6 prefix ("::ffff:10.8.0.42" → "10.8.0.42").
  const raw = req.socket.remoteAddress || "";
  const ip = raw.replace(/^::ffff:/, "");
  return readSessionMap()[ip] || null;
}

// Express middleware. Tags req with vpnCN and 403s a bootstrap-tunnel
// request if the requested path isn't in BOOTSTRAP_ALLOWED_PATHS.
//
// Design choice: when the session map has no entry for the source IP
// (e.g., OpenVPN hooks aren't installed yet), the guard allows the
// request through and downstream JWT auth still applies. Flip the
// `cn === null` branch to reject if you want strict mode.
function vpnIdentityGuard(req, res, next) {
  const cn = commonNameForRequest(req);
  req.vpnCN = cn;

  if (cn === DEFAULT_BOOTSTRAP_CN && !BOOTSTRAP_ALLOWED_PATHS.has(req.path)) {
    console.warn(
      `[GUARD] Bootstrap tunnel blocked from ${req.method} ${req.path}`,
    );
    return res.status(403).json({
      error: "Bootstrap tunnel: only login and config endpoints are permitted",
      hint: "Sign in to receive your personalized VPN config",
    });
  }
  next();
}

// Apply the guard to every request before any route handler runs.
app.use(vpnIdentityGuard);

// ── JWT middleware ─────────────────────────────────────────────
function authenticate(req, res, next) {
  const authHeader = req.headers["authorization"];
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing Authorization header" });
  }
  try {
    req.user = jwt.verify(authHeader.split(" ")[1], JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: "Invalid or expired token" });
  }
}

function getUserData(req) {
  return DEMO_USERS[req.user.email] || null;
}

// ── Public endpoints ───────────────────────────────────────────

app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    message: "You are inside the VPN tunnel!",
    your_ip: req.socket.remoteAddress,
    your_cn: req.vpnCN || "unknown (session map has no entry)",
    timestamp: new Date(),
  });
});

// Simulates the company SSO gateway (Microsoft EntraID proxy).
app.post("/api/auth/login", (req, res) => {
  const { email, password } = req.body || {};

  if (!email || !password) {
    return res.status(400).json({ error: "email and password are required" });
  }

  const user = DEMO_USERS[email.toLowerCase()];
  if (!user || user.password !== password) {
    return res.status(401).json({ error: "Invalid email or password" });
  }

  const username = email.split("@")[0];
  const isAdmin = ADMIN_EMAILS.has(email.toLowerCase());

  const token = jwt.sign(
    {
      email: email.toLowerCase(),
      username,
      name: user.name,
      employeeId: user.employeeId,
      isAdmin,
    },
    JWT_SECRET,
    { expiresIn: "8h" },
  );

  console.log(
    `[AUTH] Login successful: ${email}${isAdmin ? " (admin)" : ""}`,
  );
  res.json({ token, username, isAdmin });
});

// ── Protected endpoints ────────────────────────────────────────

// Generates (or reuses) a unique client cert per user via easy-rsa and
// returns a fully self-contained personalized .ovpn file.
app.get("/api/vpn/config", authenticate, (req, res) => {
  const { username, name, employeeId } = req.user;

  try {
    ensureClientCert(username);
    const config = buildOvpnConfig(username, name, employeeId);
    console.log(`[VPN CONFIG] Issued personalized config for ${username}`);
    res.type("text/plain").send(config);
  } catch (e) {
    console.error(
      `[VPN CONFIG] Error generating config for ${username}:`,
      e.message,
    );
    res
      .status(500)
      .json({ error: "Failed to generate VPN config", detail: e.message });
  }
});

app.get("/api/employee/profile", authenticate, (req, res) => {
  const user = getUserData(req);
  if (!user) return res.status(404).json({ error: "Employee not found" });

  res.json({
    username: req.user.username,
    name: user.name,
    email: req.user.email,
    department: user.department,
    position: user.position,
    employeeId: user.employeeId,
    joinDate: user.joinDate,
  });
});

app.get("/api/leaves/balance", authenticate, (req, res) => {
  const user = getUserData(req);
  if (!user) return res.status(404).json({ error: "Employee not found" });

  const b = user.leaveBalance;
  res.json({
    annual: {
      ...b.annual,
      remaining: b.annual.total - b.annual.used,
      label: "Annual",
    },
    sick: { ...b.sick, remaining: b.sick.total - b.sick.used, label: "Sick" },
    emergency: {
      ...b.emergency,
      remaining: b.emergency.total - b.emergency.used,
      label: "Emergency",
    },
  });
});

app.get("/api/leaves/recent", authenticate, (req, res) => {
  const user = getUserData(req);
  if (!user) return res.status(404).json({ error: "Employee not found" });
  res.json(user.recentLeaves);
});

app.get("/api/clocking/today", authenticate, (req, res) => {
  const user = getUserData(req);
  if (!user) return res.status(404).json({ error: "Employee not found" });

  const c = user.clocking;
  let hoursWorked = null;
  if (c.clockInIso) {
    hoursWorked = (
      (Date.now() - new Date(c.clockInIso).getTime()) /
      3_600_000
    ).toFixed(1);
  }

  res.json({
    date: new Date().toISOString().split("T")[0],
    clockIn: c.clockIn,
    clockOut: null,
    hoursWorked,
    status: c.status,
    location: c.location,
  });
});

// ── Admin endpoints ────────────────────────────────────────────

// List all users with their cert + CCD status. Used by the Flutter
// admin dashboard.
app.get("/api/admin/users", requireAdmin, (req, res) => {
  const users = Object.entries(DEMO_USERS).map(([email, u]) => {
    const username = email.split("@")[0];
    const certPath = path.join(PKI_DIR, "issued", `${username}.crt`);
    const ccdPath = path.join(CCD_DIR, username);
    return {
      email,
      username,
      name: u.name,
      department: u.department,
      position: u.position,
      employeeId: u.employeeId,
      isAdmin: ADMIN_EMAILS.has(email),
      certIssued: fs.existsSync(certPath),
      ccdActive: fs.existsSync(ccdPath),
    };
  });
  res.json(users);
});

// List currently active VPN sessions (read directly from the session map).
app.get("/api/admin/sessions", requireAdmin, (req, res) => {
  const map = readSessionMap();
  const sessions = Object.entries(map).map(([tunnelIp, commonName]) => ({
    tunnelIp,
    commonName,
  }));
  res.json(sessions);
});

// Revoke a user's certificate. Requires the X-Admin-Token header.
//   curl -X POST http://10.8.0.1:3000/api/admin/revoke \
//        -H "X-Admin-Token: <token>" \
//        -H "Content-Type: application/json" \
//        -d '{"username":"gideon.dakore"}'
app.post("/api/admin/revoke", requireAdmin, (req, res) => {
  const { username } = req.body || {};
  if (!username || typeof username !== "string") {
    return res.status(400).json({ error: "username (string) is required" });
  }
  if (username === DEFAULT_BOOTSTRAP_CN) {
    return res
      .status(400)
      .json({ error: "Refusing to revoke the bootstrap certificate" });
  }

  try {
    revokeUser(username);
    res.json({
      status: "revoked",
      username,
      message: `Cert revoked, CRL regenerated, CCD removed${
        fs.existsSync(OPENVPN_MGMT_SOCKET) ? ", active tunnel kicked" : ""
      }`,
    });
  } catch (e) {
    console.error(`[ADMIN] Revoke failed for ${username}:`, e.message);
    res.status(500).json({ error: "Revocation failed", detail: e.message });
  }
});

// Force-regenerate the CRL (useful for the periodic-renewal cron).
app.post("/api/admin/crl/regenerate", requireAdmin, (req, res) => {
  try {
    regenerateCRL();
    res.json({ status: "regenerated", path: OPENVPN_CRL_PATH });
  } catch (e) {
    console.error(`[ADMIN] CRL regen failed:`, e.message);
    res.status(500).json({ error: "CRL regeneration failed", detail: e.message });
  }
});

// ── Start ──────────────────────────────────────────────────────
app.listen(PORT, HOST, () => {
  console.log(`ARMS demo API listening on http://${HOST}:${PORT}`);
  console.log(`  POST /api/auth/login          — SSO simulation`);
  console.log(
    `  GET  /api/vpn/config          — personalized .ovpn (cert auto-generated) [JWT]`,
  );
  console.log(`  GET  /api/employee/profile    — employee info    [JWT]`);
  console.log(`  GET  /api/leaves/balance      — leave balance    [JWT]`);
  console.log(`  GET  /api/leaves/recent       — recent requests  [JWT]`);
  console.log(`  GET  /api/clocking/today      — today attendance [JWT]`);
  console.log(``);
  console.log(`Admin (X-Admin-Token header OR admin JWT):`);
  console.log(`  GET  /api/admin/users            — list all users`);
  console.log(`  GET  /api/admin/sessions         — active VPN sessions`);
  console.log(`  POST /api/admin/revoke           — revoke a user's cert`);
  console.log(`  POST /api/admin/crl/regenerate   — refresh the CRL`);
  console.log(
    `  Admin emails: ${[...ADMIN_EMAILS].join(", ") || "(none)"}`,
  );
  console.log(``);
  console.log(`Identity guard:`);
  console.log(`  Bootstrap CN  = ${DEFAULT_BOOTSTRAP_CN}`);
  console.log(`  Sessions file = ${SESSIONS_FILE}`);
  console.log(`  CCD dir       = ${CCD_DIR}`);
  console.log(
    `  Bootstrap is allowed: ${[...BOOTSTRAP_ALLOWED_PATHS].join(", ")}`,
  );
});
