import 'package:dio/dio.dart';

/// Turns a thrown object into a sentence a player can read.
///
/// Screens must never render `e.toString()` — a Dart exception string leaks
/// stack detail, endpoint paths and Dio internals into the UI. Every `.when`
/// error branch and every `catch` that shows a message routes through here.
String apiErrorMessage(Object error,
    {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) return _fromDio(error, fallback);

  // AuthNotifier rethrows its already-humanised text wrapped in an Exception.
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    final unwrapped = text.substring('Exception: '.length).trim();
    // Only trust it if it reads like a sentence, not like a stack trace.
    if (unwrapped.isNotEmpty &&
        !unwrapped.contains('\n') &&
        unwrapped.length < 160) {
      return unwrapped;
    }
  }
  return fallback;
}

String _fromDio(DioException e, String fallback) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The connection timed out. Please check your network and try again.';
    case DioExceptionType.connectionError:
      return 'No internet connection. Please check your network and try again.';
    case DioExceptionType.cancel:
      return 'Request cancelled.';
    case DioExceptionType.badCertificate:
      return 'Could not establish a secure connection.';
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  // Prefer the server's own message — the API envelope always carries one.
  final data = e.response?.data;
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();

    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      if (first is Map && first['message'] is String) {
        return (first['message'] as String).trim();
      }
    }
  }

  switch (e.response?.statusCode) {
    case 400:
      return 'That request could not be processed. Please check your details.';
    case 401:
      return 'Your session has expired. Please sign in again.';
    case 403:
      return 'You do not have permission to do that.';
    case 404:
      return 'We could not find what you were looking for.';
    case 409:
      return 'That slot is no longer available. Please pick another.';
    case 422:
      return 'Some details were not valid. Please review and try again.';
    case 429:
      return 'Too many attempts. Please wait a moment and try again.';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'Our servers are having trouble. Please try again shortly.';
  }
  return fallback;
}
