import 'package:dio/dio.dart';
import '../network/api_client.dart';

class AuthService {
  /// Extracts the username portion from a company email.
  /// e.g. gideon.dakore@amalitech.com → gideon.dakore
  String extractUsername(String email) => email.split('@').first;

  /// Authenticates against the Microsoft SSO endpoint exposed through the VPN
  /// server. Returns the JWT, the username, and an isAdmin flag.
  Future<({String token, String username, bool isAdmin})> login(
    String email,
    String password,
  ) async {
    final response = await ApiClient.instance.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final token = response.data['token'] as String;
    final username = extractUsername(email);
    final isAdmin = response.data['isAdmin'] as bool? ?? false;

    ApiClient.setAuthToken(token);
    return (token: token, username: username, isAdmin: isAdmin);
  }

  /// Requests the personalized .ovpn config from the VPN Config Service.
  /// Must be called after [login] so that the Authorization header is set.
  Future<String> fetchPersonalizedConfig() async {
    final response = await ApiClient.instance.get(
      '/vpn/config',
      options: Options(responseType: ResponseType.plain),
    );
    return response.data as String;
  }
}
