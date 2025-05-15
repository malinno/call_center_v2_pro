class ZSolutionConfig {
  // Base URLs
  static const String baseUrl = 'https://gateway.api.staging.zsolution.vn';
  static const String apiVersion = 'v1';

  // Authentication
  static const String loginUrl = '$baseUrl/softphone/Users/Login';
  
  // Phone endpoints
  static const String phoneBaseUrl = '$baseUrl/softphone/Phones';
  static const String companyServersUrl = '$phoneBaseUrl/company/servers';
  
  // Call History endpoints
  static const String callHistoryBaseUrl = '$baseUrl/softphone/CallHistory';
  static const String callHistorySearchUrl = '$callHistoryBaseUrl/search';

  // API Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Other configurations
  static const int defaultPageSize = 50;
  static const int callHistoryDays = 7;
} 