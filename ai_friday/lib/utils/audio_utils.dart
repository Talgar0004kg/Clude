import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AudioUtils {
  static Future<String> getTempPath(String filename) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$filename';
  }

  static Future<void> deleteTempFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
