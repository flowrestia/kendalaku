import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';

class ApiClient {
  late final Dio dio;

  static const String tokenKey = 'kendalaku_auth_token';
  static const String userKey = 'kendalaku_user_data';

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Tangani format error standar backend KendalaKu
          String errorMessage = 'Terjadi kesalahan pada sistem';
          if (e.response?.data != null && e.response?.data is Map) {
            final data = e.response!.data as Map;
            if (data['error'] != null && data['error'] is Map) {
              final errMap = data['error'] as Map;
              if (errMap['message'] != null) {
                errorMessage = errMap['message'].toString();
              }
            }
          } else if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            errorMessage = 'Batas waktu koneksi habis. Silakan periksa jaringan';
          } else if (e.type == DioExceptionType.connectionError) {
            errorMessage = 'Tidak dapat terhubung ke server backend KendalaKu';
          }

          final customException = DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: errorMessage,
            message: errorMessage,
          );

          return handler.next(customException);
        },
      ),
    );
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userKey);
  }
}
