import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

class FileService {
  static Future<Directory> getAppDir() => getApplicationDocumentsDirectory();

  static Future<String> saveText(String filename, String content) async {
    final dir = await getAppDir();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    AppLogger.info('Saved file: $filename');
    return file.path;
  }

  static Future<String?> readText(String filename) async {
    try {
      final dir = await getAppDir();
      final file = File('${dir.path}/$filename');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      AppLogger.error('Failed to read file', e);
      return null;
    }
  }
}
