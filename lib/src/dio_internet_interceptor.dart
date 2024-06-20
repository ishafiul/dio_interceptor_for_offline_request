import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_internet_interceptor/src/db_object.dart';
import 'package:dio_internet_interceptor/src/extension.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class DioExeptionHander {
  DioExeptionHander({required this.err, required this.handler});

  final DioException err;
  final ErrorInterceptorHandler handler;
}

class DioInternetInterceptor extends Interceptor {
  const DioInternetInterceptor({
    this.onDioRequest,
    this.onDioError,
    this.hasConnection,
    this.offlineResponseHandler,
    this.offlineRequestHandler,
  });

  final RequestOptions Function(RequestOptions options)? onDioRequest;
  final void Function(RequestOptions options, RequestInterceptorHandler handler)? offlineRequestHandler;
  final void Function(Response response)? offlineResponseHandler;
  final void Function(bool isConnected)? hasConnection;
  final DioExeptionHander Function(DioException err, ErrorInterceptorHandler handler)? onDioError;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final reqOptions = onDioRequest?.call(options);

    final result = await InternetConnectionChecker().hasConnection;
    if (result == false) {
      hasConnection?.call(result);
      if (reqOptions?.isOfflineApi != null && reqOptions?.isOfflineApi == true) {
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

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    offlineResponseHandler?.call(response);
    super.onResponse(response, handler);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final result = onDioError?.call(err, handler);
    super.onError(result?.err ?? err, result?.handler ?? handler);
  }

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
      final data = json.encode(options.data).replaceAll('"', '\\"');
      components.add('-d "$data"');
    }

    components.add('"${options.uri.toString()}"');

    return components.join(' ');
  }

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

    final dynamic body = _extractBodyFromCurl(curl)?.replaceAll('\\', '');

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
  Map<String, dynamic> _extractHeadersFromCurl(String curl) {
    final regex = RegExp(r'-H\s+"([^"]+)"');
    final Iterable<Match> matches = regex.allMatches(curl);

    final headersMap = <String, dynamic>{};

    matches.forEach((match) {
      final headerString = match.group(1)!;
      final parts = headerString.split(':');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final value = parts[1].trim();
        headersMap[name] = value;
      }
    });

    return headersMap;
  }

  String? _extractBodyFromCurl(String curl) {
    final regex = RegExp(r'-d\s+"({.*?})"');
    final Match? match = regex.firstMatch(curl);

    return match?.group(1);
  }


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
