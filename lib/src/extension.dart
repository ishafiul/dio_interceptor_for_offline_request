import 'package:dio/dio.dart';

extension DioRequestExtension on RequestOptions {
  /// For setting the flag value of is Offline support or not
  set isOfflineApi(bool status) => extra['isOfflineApi'] = status;

  bool get isOfflineApi =>
      extra['isOfflineApi'] != null ? extra['isOfflineApi'] as bool : false;
}
