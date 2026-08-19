class AppConstants {
  // Branding
  static const String appName = 'Playsher';

  // Change to your PC's IP when testing on physical device
  // Android emulator: 10.0.2.2   |   iOS simulator: localhost
  static const String baseUrl = 'https://playsher-api.vercel.app/api/v1';

  // Secure storage keys
  static const String accessTokenKey  = 'playsher_access_token';
  static const String refreshTokenKey = 'playsher_refresh_token';
  static const String userKey         = 'playsher_user';

  // Pagination
  static const int defaultPageSize = 20;

  // Currency
  static const String currency = '\u20b9';

  // Razorpay
  static const String razorpayKeyId = 'rzp_test_SfE44aZxtFrhgU';
}
