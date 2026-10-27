import 'server_config.dart';

class AppConfig {
  // Android Emulator: 10.0.2.2 points to the development PC.
  // A physical phone can use `adb reverse tcp:8080 tcp:8080`, a LAN IP, or a
  // public URL. The value can be overridden at build time with
  // --dart-define=TAHANAN_API_URL and at runtime from More -> Server address.
  static String get apiBaseUrl => ServerConfig.baseUrl;

  // Use the OAuth Web client ID for Web and as serverClientId for Android/iOS.
  // This is a public identifier: it ships inside the web bundle and is sent to
  // Google in the clear. Never put the OAuth *client secret* in the app.
  static const googleWebClientId = String.fromEnvironment(
    'TAHANAN_GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '342273422895-4rar0nfdg8e2080mq4ugh2m18em6ik52.apps.googleusercontent.com',
  );

  // Android does not need a client ID in code: the plugin selects the Android
  // OAuth client registered in Google Cloud Console for this package name and
  // signing SHA-1. This constant only exists so a specific Android client can
  // be forced, and must belong to the same project as the web client above.
  static const googleAndroidClientId = String.fromEnvironment(
    'TAHANAN_GOOGLE_ANDROID_CLIENT_ID',
    defaultValue:
        '342273422895-btvs01rbp3nhu8nh4ednpntl8kbdc1gp.apps.googleusercontent.com',
  );
}
