import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  static Future<bool> requestAll() async {
    final statuses = await [
      Permission.microphone,
      Permission.contacts,
      Permission.phone,
      Permission.notification,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  static Future<bool> hasMicrophone() => Permission.microphone.isGranted;
  static Future<bool> hasContacts() => Permission.contacts.isGranted;
  static Future<bool> hasPhone() => Permission.phone.isGranted;
}
