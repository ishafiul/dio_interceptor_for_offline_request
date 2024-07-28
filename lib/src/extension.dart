import 'package:dio/dio.dart';

/// An extension on [RequestOptions] to add offline support functionality.
extension DioRequestExtension on RequestOptions {
  /// Sets the flag value indicating whether the API request supports offline mode.
  ///
  /// [status] is a boolean value that determines if the API request supports offline mode.
  set isOfflineApi(bool status) => extra['isOfflineApi'] = status;

  /// Gets the flag value indicating whether the API request supports offline mode.
  ///
  /// Returns `true` if the API request supports offline mode, otherwise `false`.
  bool get isOfflineApi =>
      extra['isOfflineApi'] != null ? extra['isOfflineApi'] as bool : false;
}
