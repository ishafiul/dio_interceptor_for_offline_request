import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_internet_interceptor/src/db_object.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class DioExeptionHander {
  DioExeptionHander({required this.err, required this.handler});

  final DioException err;
  final ErrorInterceptorHandler handler;
}

/// {@template dio_internet_interceptor}
/// dio interceptor
/// {@endtemplate}
class DioInternetInterceptor extends Interceptor {
  /// {@macro dio_internet_interceptor}
  const DioInternetInterceptor({
    required this.onDioRequest,
    required this.onDioError,
    this.hasConnection,
  });

  final RequestOptions Function(RequestOptions options) onDioRequest;
  final void Function({bool isConnected})? hasConnection;
  final DioExeptionHander Function(
    DioException err,
    ErrorInterceptorHandler handler,
  ) onDioError;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final reqOptions = onDioRequest(options);

    final result = await InternetConnectionChecker().hasConnection;
    if (result == false) {
      if (options.method.toUpperCase() == 'GET') {
        hasConnection?.call(isConnected: result);
        return;
      }
      final curl = _cURLRepresentation(reqOptions);
      final curlService = CurlService();
      await curlService.addCurl(curl);
      final value = await curlService.getCurls();
     /* value?.forEach((element) {
        curlService.deleteCurl(value.indexOf(element));
      });*/
      print(value);
      hasConnection?.call(isConnected: result);
      return;
    } else {
      print(options.data);
      await _makeRequest();
      handler.next(reqOptions);
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final result = onDioError(err, handler);
    super.onError(result.err, result.handler);
  }

  String _cURLRepresentation(RequestOptions options) {
    final List<String> components = ['curl -i'];
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
    // Split the string by spaces to get individual parts

    final parts = curl.split(' ');

    // Extract method from the parts
    var method = 'GET';
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == '-X' && i + 1 < parts.length) {
        method = parts[i + 1];
        break;
      }
    }

    // Extract URL from the last part
    final urlIndex = parts.indexWhere((part) {
      return part.startsWith('"http');
    });
    if (urlIndex == -1) {
      throw ArgumentError('No URL specified in the cURL command.');
    }
    final url = parts.sublist(urlIndex).join(' ').replaceAll('"', '');

    // Extract headers from the parts
    final headers = extractHeadersFromCurl(curl);

    // Extract body from the parts
    dynamic body;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == '-d' && i + 1 < parts.length) {
        // Extract the data section (inside double quotes)
        String dataSection = parts[i + 1];

        // Remove surrounding double quotes and escape characters from the data section
        dataSection = dataSection.replaceAll('"', '');

        // Decode the JSON string into a Dart object
        try {
          body = json.decode(dataSection);
        } catch (e) {
          throw FormatException('Error parsing request body: $e');
        }
        break;
      }
    }

    // Create RequestOptions object
    final options = RequestOptions(
      method: method,
      headers: headers,
      data: body,
      queryParameters: {},
      // Assuming baseUrl is not specified in the cURL command
    );

    // Set URL in RequestOptions
    final uri = Uri.parse(url);
    print(uri.host);
    options
      ..baseUrl = '${uri.scheme}://${uri.host}${uri.path}'
      ..queryParameters = uri.queryParameters;

    return options;
  }

  Map<String, dynamic> extractBodysFromCurl(String curl) {
    final bodyMap = <String, dynamic>{};

    // Split the curl command by spaces to analyze each part
    final parts = curl.split(' ');

    for (var i = 0; i < parts.length; i++) {
      // Look for the '-d' flag
      if (parts[i] == '-d' && i + 1 < parts.length) {
        // Extract the data section
        final dataSection = parts[i + 1];

        // Check if it starts with '{' and ends with '}', indicating a JSON object
        if (dataSection.startsWith('{') && dataSection.endsWith('}')) {
          try {
            // Parse the JSON string into a map
            final parsedData = json.decode(dataSection);

            // Add each key-value pair from the parsed data into the bodyMap
            parsedData.forEach((String key, value) {
              String cleanedKey = key.replaceAll(r'\', '');
              bodyMap["$cleanedKey "] = ("$value " as String).replaceAll(r'\', '');
            });

            // Break the loop since we found and parsed the data section
            break;
          } catch (e) {
            // Handle any parsing errors here if needed
            print('Error parsing data section: $e');
          }
        } else {
          // Handle cases where the data section format is unexpected
          print('Unexpected data section format: $dataSection');
        }
      }
    }

    return bodyMap;
  }

  Map<String, dynamic> extractHeadersFromCurl(String curl) {
    // Initialize an empty map to store headers
    final headers = <String, dynamic>{};

    // Split the string by spaces to get individual parts
    final parts = curl.split(' ');

    // Iterate over the parts to find headers
    for (var i = 0; i < parts.length; i++) {
      // If the current part starts with '-H' and there's a next part
      if (parts[i] == '-H' && i + 1 < parts.length) {
        // Get the next part as the header string
        final headerString = parts[i + 1];

        // Remove leading and trailing double quotes from the header string
        final cleanedHeaderString = headerString.replaceAll('"', '');

        // Split the cleaned header string by colon ':' to separate name and value
        final headerParts = cleanedHeaderString.split(':');

        // Ensure the header string is properly formatted
        if (headerParts.length == 2) {
          // Trim leading and trailing whitespace from name and value
          final name = headerParts[0].trim();
          final value = headerParts[1].trim();

          // Add the header to the map
          headers[name] = value;
        }
      }
    }

    // Return the extracted headers
    return headers;
  }

  Options requestOptionsToOptions(RequestOptions requestOptions) {
    return Options(
      method: requestOptions.method,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
      extra: requestOptions.extra,
      headers: requestOptions.headers,
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
    final curlList = <Map<String, dynamic>>[];
    if (curls != null) {
      for (final curl in curls) {
        final index = curls.indexOf(curl);
        await curlService.deleteCurl(index).then((value) {
          final reqOptions = _curlRepresentationToOptions(curl);
          final options = requestOptionsToOptions(reqOptions);
          curlList.add({reqOptions.baseUrl: options});
        });
      }
    }

    await Future.wait(
      List.generate(
        curlList.length,
        (index) => dio.request(
          curlList[0].keys.first,
          options: curlList[0].values.first as Options,
        ),
      ),
    );
  }
}
