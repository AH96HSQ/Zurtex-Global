import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
  }

  static String get backendBaseUrl {
    return dotenv.env['BACKEND_BASE_URL'] ??
        'http://zurtexbackend569827.xyz/melli';
  }

  static String get backendBackupUrl {
    return dotenv.env['BACKEND_BACKUP_URL'] ??
        'http://zurtexbackend198267.xyz:8080/melli';
  }

  static List<String> get domainCandidates {
    return [backendBaseUrl, backendBackupUrl];
  }

  static bool get isProductionMode {
    return dotenv.env['ENVIRONMENT'] == 'production';
  }
}
