import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

/// A service for managing cURL commands using Hive for local storage.
class CurlService {
  /// The name of the Hive box where cURL commands are stored.
  final String _hiveBoxName = 'curl';

  /// Opens a Hive box for storing cURL commands.
  ///
  /// This method initializes the Hive database in the application's
  /// document directory and opens a box with the name [_hiveBoxName].
  ///
  /// Returns a [Box] containing a list of cURL command strings.
  Future<Box<List<String>>> _openBox() async {
    final appDocumentDir =
    await path_provider.getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    return Hive.openBox<List<String>>(_hiveBoxName);
  }

  /// Adds a new cURL command to the Hive box.
  ///
  /// This method retrieves the existing list of cURL commands from the
  /// Hive box, adds the new command, and updates the box.
  ///
  /// [curl] is the cURL command to be added.
  Future<void> addCurl(String curl) async {
    final box = await _openBox();
    final curls = box.get('curlList', defaultValue: []);
    curls?.add(curl);
    await box.put('curlList', curls ?? []);
    await box.close();
  }

  /// Retrieves the list of cURL commands from the Hive box.
  ///
  /// This method opens the Hive box, retrieves the list of cURL commands,
  /// and closes the box.
  ///
  /// Returns a list of cURL command strings or null if no commands are found.
  Future<List<String>?> getCurls() async {
    final box = await _openBox();
    final curls = box.get('curlList', defaultValue: []);
    await box.close();
    return curls;
  }

  /// Deletes a cURL command from the Hive box by index.
  ///
  /// This method retrieves the existing list of cURL commands from the
  /// Hive box, removes the command at the specified index, and updates the box.
  ///
  /// [index] is the position of the cURL command to be removed.
  Future<void> deleteCurl(int index) async {
    final box = await _openBox();
    final curls = box.get('curlList', defaultValue: []);
    curls?.removeAt(index);
    await box.put('curlList', curls ?? []);
    await box.close();
  }
}
