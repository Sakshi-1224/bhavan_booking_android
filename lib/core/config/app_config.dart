class AppConfig {
  // Use '127.0.0.1' when testing on a physical device via USB 
  // after running BOTH commands: 
  // adb reverse tcp:3000 tcp:3000
  // adb reverse tcp:9000 tcp:9000
  static const String apiHost = '127.0.0.1'; 
  
  // Use '10.0.2.2' ONLY when testing on the Android Emulator
  // static const String apiHost = '10.0.2.2';

  static const String apiPort = '4000';
  static const String apiBaseUrl = 'http://$apiHost:$apiPort/api/v1';
}
 