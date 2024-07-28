import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_internet_interceptor/src/db_object.dart';
import 'package:dio_internet_interceptor/src/extension.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// A class to handle Dio exceptions and provide descriptive error messages.
class DioExceptionHandler {
  /// Creates an instance of [DioExceptionHandler] with the given Dio exception
  /// and error interceptor handler.
  ///
  /// The [err] parameter is the Dio exception that occurred.
  /// The [handler] parameter is the error interceptor handler to manage the error.
  DioExceptionHandler({
    required this.err,
    required this.handler,
  });

  /// The Dio exception that occurred.
  final DioException err;

  /// The error interceptor handler to manage the error.
  final ErrorInterceptorHandler handler;
}

/// A custom Dio interceptor to handle internet connectivity and offline requests.
class DioInternetInterceptor extends Interceptor {
  /// Creates an instance of [DioInternetInterceptor] with optional callbacks.
  ///
  /// The [onDioRequest] callback is called before the request is sent.
  /// The [onDioError] callback is called when an error occurs during the request.
  /// The [hasConnection] callback is called to check internet connectivity.
  /// The [offlineResponseHandler] callback is called to handle the response when offline.
  /// The [offlineRequestHandler] callback is called to handle the request when offline.
  const DioInternetInterceptor({
    this.onDioRequest,
    this.onDioError,
    this.hasConnection,
    this.offlineResponseHandler,
    this.offlineRequestHandler,
  });

  /// A callback to modify the [RequestOptions] before the request is sent.
  final RequestOptions Function(RequestOptions options)? onDioRequest;

  /// A callback to handle the request when offline.
  final void Function(
      RequestOptions options,
      RequestInterceptorHandler handler,
      )? offlineRequestHandler;

  /// A callback to handle the response when offline.
  final void Function(Response response)? offlineResponseHandler;

  /// A callback to check internet connectivity.
  final void Function(bool isConnected)? hasConnection;

  /// A callback to handle Dio errors.
  final DioExceptionHandler Function(
      DioException err,
      ErrorInterceptorHandler handler,
      )? onDioError;

  /// Intercepts the request before it is sent.
  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    final reqOptions = onDioRequest?.call(options);

    final result = await InternetConnectionChecker().hasConnection;
    if (result == false) {
      hasConnection?.call(result);
      if (reqOptions?.isOfflineApi != null &&
          reqOptions?.isOfflineApi == true) {
        final curl = _cURLRepresentation(reqOptions ?? options);

        final curlService = CurlService();
        final value = await curlService.getCurls();
        if (value != null && !value.contains(curl)) {
          await curlService.addCurl(curl);
        }
        offlineRequestHandler?.call(options, handler);
      }
    } else {
      await _makeRequest();
    }
    handler.next(reqOptions ?? options);
  }

  /// Intercepts the response after it is received.
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    offlineResponseHandler?.call(response);
    super.onResponse(response, handler);
  }

  /// Intercepts errors during the request.
  @override
  Future<void> onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) async {
    final result = onDioError?.call(err, handler);
    super.onError(result?.err ?? err, result?.handler ?? handler);
  }

  /// Generates a cURL representation of the [RequestOptions].
  String _cURLRepresentation(RequestOptions options) {
    final components = <String>['curl -i'];
    if (options.method.toUpperCase() != 'GET') {
      components.add('-X ${options.method}');
    }

    options.headers.forEach((k, v) {
      if (k != 'Cookie') {
        components.add('-H "$k: $v"');
      }
    });

    if (options.data != null) {
      final data = json.encode(options.data).replaceAll('"', r'\"');
      components.add('-d "$data"');
    }

    components.add('"${options.uri}"');

    return components.join(' ');
  }

  /// Converts a cURL representation to [RequestOptions].
  RequestOptions _curlRepresentationToOptions(String curl) {
    final parts = curl.split(' ');

    var method = 'GET';
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == '-X' && i + 1 < parts.length) {
        method = parts[i + 1];
        break;
      }
    }

    final urlIndex = parts.indexWhere((part) {
      return part.startsWith('"http');
    });
    if (urlIndex == -1) {
      throw ArgumentError('No URL specified in the cURL command.');
    }
    final url = parts.sublist(urlIndex).join(' ').replaceAll('"', '');

    final headers = _extractHeadersFromCurl(curl);

    final dynamic body = _extractBodyFromCurl(curl)?.replaceAll(r'\', '');

    final options = RequestOptions(
      method: method,
      headers: headers,
      data: body,
      queryParameters: {},
    );

    final uri = Uri.parse(url);
    options
      ..baseUrl = '${uri.scheme}://${uri.host}'
      ..path = uri.path
      ..queryParameters = uri.queryParameters;

    return options;
  }

  /// Extracts headers from a cURL command.
  Map<String, dynamic> _extractHeadersFromCurl(String curl) {
    final regex = RegExp(r'-H\s+"([^"]+)"');
    final Iterable<Match> matches = regex.allMatches(curl);

    final headersMap = <String, dynamic>{};

    for (final match in matches) {
      final headerString = match.group(1)!;
      final parts = headerString.split(':');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final value = parts[1].trim();
        headersMap[name] = value;
      }
    }

    return headersMap;
  }

  /// Extracts the body from a cURL command.
  String? _extractBodyFromCurl(String curl) {
    final regex = RegExp(r'-d\s+"({.*?})"');
    final Match? match = regex.firstMatch(curl);

    return match?.group(1);
  }

  /// Converts [RequestOptions] to [Options].
  Options _requestOptionsToOptions(RequestOptions requestOptions) {
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    // Ensure we only have one 'Content-Type' header
    if (headers.containsKey('content-type')) {
      headers.remove('content-type');
    }

    return Options(
      method: requestOptions.method,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
      extra: requestOptions.extra,
      headers: headers,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      followRedirects: requestOptions.followRedirects,
      maxRedirects: requestOptions.maxRedirects,
      persistentConnection: requestOptions.persistentConnection,
      requestEncoder: requestOptions.requestEncoder,
      responseDecoder: requestOptions.responseDecoder,
      listFormat: requestOptions.listFormat,
    );
  }

  /// Makes a request based on stored cURL commands.
  Future<void> _makeRequest() async {
    final curlService = CurlService();
    final dio = Dio();
    final curls = await curlService.getCurls();

    if (curls != null) {
      for (var i = curls.length - 1; i >= 0; i--) {
        final curl = curls[i];
        await curlService.deleteCurl(i).then((value) async {
          final reqOptions = _curlRepresentationToOptions(curl);
          final options = _requestOptionsToOptions(reqOptions);

          try {
            await dio.request(
              reqOptions.baseUrl + reqOptions.path,
              options: options,
              queryParameters: reqOptions.queryParameters,
              data: reqOptions.data,
            );
          } catch (e) {
            print('Error during request at index $i: $e');
          }
        });
      }
    }
  }
}

