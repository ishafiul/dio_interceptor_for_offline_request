import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

class CurlService {
  final String _hiveBoxName = 'curl';

  Future<Box<List<String>>> _openBox() async {
    final appDocumentDir =
        await path_provider.getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    return Hive.openBox<List<String>>(_hiveBoxName);
  }

  // Define a box name

  Future<void> addCurl(String curl) async {
    final box = await _openBox();
    final curls = box.get('curlList', defaultValue: []);
    curls?.add(curl);
    await box.put('curlList', curls ?? []);
    await box.close();
  }

  Future<List<String>?> getCurls() async {
    final box = await _openBox();
    final curls = box.get('curlList', defaultValue: []);
    await box.close();
    return curls;
  }

  Future<void> deleteCurl(int index) async {
    final box = await _openBox();
    final curls = box.get('curlList', defaultValue: []);
    curls?.removeAt(index);
    await box.put('curlList', curls ?? []);
    await box.close();
  }
}
