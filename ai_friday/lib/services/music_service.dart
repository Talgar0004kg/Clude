import 'intent_service.dart';

class MusicService {
  static Future<bool> openSpotify() => IntentService.openApp('spotify');
  static Future<bool> openYouTubeMusic() => IntentService.openApp('youtube');
}
