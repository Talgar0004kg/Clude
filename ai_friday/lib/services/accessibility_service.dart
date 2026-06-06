import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/constants.dart';
import '../utils/logger.dart';

class AccessibilityServiceManager {
  static Future<bool> isEnabled() async {
    try {
      return await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    } catch (e) {
      AppLogger.error('Failed to check accessibility', e);
      return false;
    }
  }

  static Future<void> requestPermission() async {
    try {
      await FlutterAccessibilityService.requestAccessibilityPermission();
    } catch (e) {
      AppLogger.error('Failed to request accessibility', e);
    }
  }

  static Stream<AccessibilityEvent> get eventStream =>
      FlutterAccessibilityService.accessStream;

  static Future<bool> performNodeAction(NodeAction action, AccessibilityEvent event) async {
    try {
      return await FlutterAccessibilityService.performAction(event, action);
    } catch (e) {
      AppLogger.error('Failed to perform accessibility action', e);
      return false;
    }
  }

  static Future<bool> performGlobalAction(GlobalAction action) async {
    try {
      return await FlutterAccessibilityService.performGlobalAction(action);
    } catch (e) {
      AppLogger.error('Failed to perform global action', e);
      return false;
    }
  }

  static Future<List<GlobalAction>> getSystemActions() async {
    try {
      return await FlutterAccessibilityService.getSystemActions();
    } catch (e) {
      AppLogger.error('Failed to get system actions', e);
      return [];
    }
  }
}
