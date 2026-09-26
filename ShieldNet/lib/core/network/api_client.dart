import 'package:flutter/foundation.dart';
import 'package:shieldnet/core/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Client Dio intelligent avec basculement automatique d'URL
/// Permet la communication transparente entre le mobile (physique USB via adb reverse,
/// Wi-Fi LAN, ou émulateur) et le serveur Django.
class ApiClient {
  static String? _workingBaseUrl;

  static List<String> get candidateBaseUrls {
    final envUrl = dotenv.env['API_BASE_URL'];
    final urls = <String>[];
    if (envUrl != null && envUrl.isNotEmpty) {
      final formatted = envUrl.endsWith('/') ? envUrl : '$envUrl/';
      urls.add(formatted);
    }
    const fallbacks = [
      'http://127.0.0.1:8000/api/v1/',
      'http://192.168.2.17:8000/api/v1/',
      'http://10.0.2.2:8000/api/v1/',
    ];
    for (final fb in fallbacks) {
      if (!urls.contains(fb)) {
        urls.add(fb);
      }
    }
    return urls;
  }

  static String get initialBaseUrl {
    return _workingBaseUrl ?? candidateBaseUrls.first;
  }

  /// Résout la clé API d'authentification client selon la hiérarchie :
  /// 1. Paramètre de compilation --dart-define=API_KEY=...
  /// 2. Fichier d'environnement .env (variable API_KEY)
  /// 3. Mode développement uniquement (kDebugMode)
  static String get resolvedApiKey {
    const defineKey = String.fromEnvironment('API_KEY');
    if (defineKey.isNotEmpty) {
      return defineKey;
    }
    if (dotenv.isInitialized) {
      final envKey = dotenv.env['API_KEY'];
      if (envKey != null && envKey.isNotEmpty) {
        return envKey;
      }
    }
    if (kDebugMode) {
      return 'ShieldNet_Secret_Token_UQO_2026';
    }
    return '';
  }

  static Dio createDio() {
    final apiKey = resolvedApiKey;
    final dio = Dio(
      BaseOptions(
        baseUrl: initialBaseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'X-API-Key': apiKey,
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, ErrorInterceptorHandler handler) async {
          final isConnErr = err.type == DioExceptionType.connectionTimeout ||
              err.type == DioExceptionType.connectionError ||
              err.type == DioExceptionType.sendTimeout;

          if (isConnErr && err.requestOptions.extra['_hasRetried'] != true) {
            final candidates = candidateBaseUrls;
            final currentBase = dio.options.baseUrl;

            for (final candidate in candidates) {
              if (candidate == currentBase) continue;

              try {
                AppLogger.log('[ApiClient] Tentative fallback réseau vers $candidate...');
                final newOptions = Options(
                  method: err.requestOptions.method,
                  headers: err.requestOptions.headers,
                  responseType: err.requestOptions.responseType,
                  contentType: err.requestOptions.contentType,
                  extra: {
                    ...err.requestOptions.extra,
                    '_hasRetried': true,
                  },
                );

                final String rawPath = err.requestOptions.path;
                final String fullPath = rawPath.startsWith('http')
                    ? rawPath
                    : (candidate.endsWith('/') && rawPath.startsWith('/')
                        ? '$candidate${rawPath.substring(1)}'
                        : (!candidate.endsWith('/') && !rawPath.startsWith('/')
                            ? '$candidate/$rawPath'
                            : '$candidate$rawPath'));

                final retryResponse = await dio.request(
                  fullPath,
                  data: err.requestOptions.data,
                  queryParameters: err.requestOptions.queryParameters,
                  options: newOptions,
                );

                _workingBaseUrl = candidate;
                dio.options.baseUrl = candidate;
                AppLogger.log('[ApiClient] Connexion réussie sur $candidate');
                return handler.resolve(retryResponse);
              } catch (_) {
                // Essayer le candidat suivant
              }
            }
          }
          return handler.next(err);
        },
      ),
    );

    return dio;
  }
}
