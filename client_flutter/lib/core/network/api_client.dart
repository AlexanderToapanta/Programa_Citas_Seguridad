import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../security/secure_storage.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService storageService;

  ApiClient({required this.storageService}) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Manejo de expiración de sesión (RF05)
            debugPrint('[AUTH] Sesión expirada o token revocado por el backend');
          } else if (error.response?.statusCode == 429) {
            debugPrint('[SECURITY] Demasiadas peticiones. Límite de tasa alcanzado');
          }
          return handler.next(error);
        },
      ),
    );
  }

  String extractErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response != null && error.response?.data != null) {
        final data = error.response?.data;
        if (data is Map && data.containsKey('message')) {
          final msg = data['message'];
          if (msg is List) {
            return msg.join('\n');
          }
          return msg.toString();
        }
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Tiempo de espera agotado al conectar con el servidor';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'No se pudo establecer conexión con el servidor backend (${ApiConstants.baseUrl}). Verifique que el servicio esté ejecutándose.';
      }
      return 'Error de comunicación (${error.response?.statusCode ?? 'Red'})';
    }
    return error.toString();
  }
}

