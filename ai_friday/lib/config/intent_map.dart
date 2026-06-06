class IntentMap {
  static const Map<String, String> appPackages = {
    'whatsapp': 'com.whatsapp',
    'telegram': 'org.telegram.messenger',
    'instagram': 'com.instagram.android',
    'youtube': 'com.google.android.youtube',
    'maps': 'com.google.android.apps.maps',
    'google maps': 'com.google.android.apps.maps',
    'camera': 'com.android.camera',
    'settings': 'com.android.settings',
    'spotify': 'com.spotify.music',
    'chrome': 'com.android.chrome',
    'gmail': 'com.google.android.gm',
    'calendar': 'com.google.android.calendar',
    'keep': 'com.google.android.keep',
    'clock': 'com.google.android.deskclock',
    'calculator': 'com.android.calculator2',
    'files': 'com.google.android.documentsui',
    'phone': 'com.android.dialer',
    'contacts': 'com.android.contacts',
    'messages': 'com.google.android.apps.messaging',
    'play store': 'com.android.vending',
  };

  static String? getPackage(String appName) {
    return appPackages[appName.toLowerCase()];
  }
}
