# Dio Internet Interceptor
This interceptor for Dio manages API requests when there's no internet connection. It checks for connectivity, stores requests if there's no connection, provides callbacks for offline data handling, and retries failed requests when connectivity is restored.

## Features
- **Check Internet Connection:** Before each request, the interceptor checks for internet availability.
- **Store Requests:** If there's no internet, the request is stored for retrying once internet is available.
- **Offline Data Callback:** Provides a callback to handle CRUD operations with a local database when offline.
- **Response Callback:** Handles updates to the local database with new remote data once the connection is restored.
- **Retry Mechanism:** Automatically retries previously failed requests when the internet is back.

## Usage
``` dart
 final dio = Dio();
 dio.interceptors.add(DioInternetInterceptor(onDioRequest: (options) {
    options.isOfflineApi = true;
    return options;
  }, offlineResponseHandler: (response) {
    print(response);
  }, onDioError: (DioException err, ErrorInterceptorHandler handler) {
    return DioExceptionHandler(err: err, handler: handler);
  }));
  dio.options.headers['key'] = 'value';

  dio.post(
        'https://httpbin.org/post',
        data: {"bodyKey": "bodyValue", "key": "value"},
        onSendProgress: (count, total) {
          print(count);
          print(total);
        },
      );

```
