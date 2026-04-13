class AppConfig {
  static const bool isDev = false;

  static const String devBaseUrl = 'http://192.168.1.17:3000';
  static const String prodBaseUrl = 'https://whatsapp.enviableinvestment.com';

  static String get baseUrl => isDev ? devBaseUrl : prodBaseUrl;
  static String get wsUrl => baseUrl;
}
