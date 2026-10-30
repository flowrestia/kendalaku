import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

enum ErrorType {
  noConnection,
  unauthorized,
  forbidden,
  notFound,
  validation,
  serverError,
  unexpected,
}

class AppError {
  final ErrorType type;
  final String message;
  final int? statusCode;
  final Object? originalError;

  const AppError({
    required this.type,
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => message;
}

class ErrorMapper {
  static const String noConnectionMessage =
      'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.';
  static const String unauthorizedMessage =
      'Sesi berakhir, silakan masuk lagi';
  static const String forbiddenMessage =
      'Kamu tidak punya akses untuk aksi ini';
  static const String notFoundMessage = 'Data tidak ditemukan';
  static const String serverErrorMessage =
      'Terjadi gangguan di server. Coba beberapa saat lagi.';
  static const String unexpectedMessage = 'Terjadi kesalahan tak terduga.';

  static AppError map(dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ErrorMapper] ${error.runtimeType}: $error');
      if (stackTrace != null) {
        debugPrint('[ErrorMapper Stack] $stackTrace');
      }
    }

    if (error == null) {
      return const AppError(
        type: ErrorType.unexpected,
        message: unexpectedMessage,
      );
    }

    // 1. DioException
    if (error is DioException) {
      // Masalah koneksi fisik / timeout
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          error.error is SocketException) {
        return AppError(
          type: ErrorType.noConnection,
          message: noConnectionMessage,
          originalError: error,
        );
      }

      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        if (statusCode == 401) {
          return AppError(
            type: ErrorType.unauthorized,
            message: unauthorizedMessage,
            statusCode: 401,
            originalError: error,
          );
        } else if (statusCode == 403) {
          return AppError(
            type: ErrorType.forbidden,
            message: forbiddenMessage,
            statusCode: 403,
            originalError: error,
          );
        } else if (statusCode == 404) {
          return AppError(
            type: ErrorType.notFound,
            message: notFoundMessage,
            statusCode: 404,
            originalError: error,
          );
        } else if (statusCode == 400 || statusCode == 422) {
          String validationMsg = _extractServerMessage(error.response?.data);
          if (validationMsg.isEmpty) {
            validationMsg = 'Data yang dikirim tidak valid.';
          }
          return AppError(
            type: ErrorType.validation,
            message: validationMsg,
            statusCode: statusCode,
            originalError: error,
          );
        } else if (statusCode >= 500 && statusCode < 600) {
          return AppError(
            type: ErrorType.serverError,
            message: serverErrorMessage,
            statusCode: statusCode,
            originalError: error,
          );
        }
      }

      // DioException cancel
      if (error.type == DioExceptionType.cancel) {
        return AppError(
          type: ErrorType.unexpected,
          message: unexpectedMessage,
          originalError: error,
        );
      }

      // Jika ada error message custom yang bukan nama exception
      if (error.message != null &&
          error.message!.isNotEmpty &&
          !error.message!.contains('DioException')) {
        return AppError(
          type: ErrorType.unexpected,
          message: error.message!,
          originalError: error,
        );
      }

      return AppError(
        type: ErrorType.noConnection,
        message: noConnectionMessage,
        originalError: error,
      );
    }

    // 2. Network Exceptions
    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException) {
      return AppError(
        type: ErrorType.noConnection,
        message: noConnectionMessage,
        originalError: error,
      );
    }

    // 3. TypeError & FormatException
    if (error is TypeError || error is FormatException) {
      return AppError(
        type: ErrorType.unexpected,
        message: unexpectedMessage,
        originalError: error,
      );
    }

    // 4. String plain
    if (error is String) {
      final lower = error.toLowerCase();
      if (lower.contains('socket') ||
          lower.contains('koneksi') ||
          lower.contains('connection') ||
          lower.contains('timeout')) {
        return AppError(
          type: ErrorType.noConnection,
          message: noConnectionMessage,
          originalError: error,
        );
      }
      return AppError(
        type: ErrorType.unexpected,
        message: error,
        originalError: error,
      );
    }

    // 5. Standard Exception
    if (error is Exception) {
      final msg = error.toString().replaceFirst('Exception: ', '').trim();
      final lower = msg.toLowerCase();
      if (lower.contains('socket') ||
          lower.contains('koneksi') ||
          lower.contains('connection') ||
          lower.contains('timeout')) {
        return AppError(
          type: ErrorType.noConnection,
          message: noConnectionMessage,
          originalError: error,
        );
      }
      return AppError(
        type: ErrorType.unexpected,
        message: unexpectedMessage,
        originalError: error,
      );
    }

    // 6. Fallback lain
    return AppError(
      type: ErrorType.unexpected,
      message: unexpectedMessage,
      originalError: error,
    );
  }

  static String getMessage(dynamic error, [StackTrace? stackTrace]) {
    return map(error, stackTrace).message;
  }

  static String _extractServerMessage(dynamic data) {
    if (data is Map) {
      if (data['error'] is Map) {
        final errMap = data['error'] as Map;
        if (errMap['message'] != null && errMap['message'].toString().isNotEmpty) {
          return errMap['message'].toString();
        }
      }
      if (data['message'] != null && data['message'].toString().isNotEmpty) {
        return data['message'].toString();
      }
    }
    return '';
  }
}

