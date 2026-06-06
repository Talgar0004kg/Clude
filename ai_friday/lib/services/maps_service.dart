import 'intent_service.dart';

class MapsService {
  static Future<bool> navigate(String destination) =>
      IntentService.openMaps(destination);

  static Future<bool> findNearby(String placeType) =>
      IntentService.openMaps('ближайший $placeType');
}
