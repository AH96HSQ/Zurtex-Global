import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/vpn_account.dart';
import '../constants/api_config.dart'; // ⬅️ where ApiConfig.baseUrl is defined

class VpnLinkService {
  static final List<String> domainCandidates = [
    '45.138.132.39:3000', // fallback last
  ];

  static Future<VpnAccount?> getVpnAccount(String deviceId) async {
    for (final domain in domainCandidates) {
      final url = 'http://$domain/api/subscription';

      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'deviceId': deviceId}),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final account = VpnAccount.fromJson(data);

          // ✅ update global base URL
          ApiConfig.baseUrl = domain;

          return account;
        }
      } on TimeoutException {
        continue;
      } catch (_) {
        continue;
      }
    }

    // ❌ All attempts failed
    return null;
  }
}
