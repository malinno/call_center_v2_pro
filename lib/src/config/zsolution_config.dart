class ZSolutionConfig {
  static const String baseUrl = 'https://gateway.api.staging.zsolution.vn';
  static const String loginEndpoint = '/softphone/Users/Login';

  static String get loginUrl => '$baseUrl$loginEndpoint';
} 