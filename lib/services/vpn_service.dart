import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zurtex/constants/api_config.dart';
import '../models/vpn_account.dart';

class VpnService {
  static final List<String> domainCandidates = [
    'zurtex.net', // 🔒 HTTPS primary domain
  ];

  /// Get VPN account (POST /api/subscription)
  static Future<VpnAccount?> getVpnAccount(String deviceId) async {
    for (final domain in domainCandidates) {
      final url = domain.startsWith('http')
          ? '$domain/api/subscription'
          : 'https://$domain/api/subscription';

      debugPrint('📡 POST: $url');

      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'deviceId': deviceId}),
            )
            .timeout(const Duration(seconds: 5));

        debugPrint('📶 Response: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          ApiConfig.baseUrl = domain;
          return VpnAccount.fromJson(data);
        }
      } on TimeoutException {
        debugPrint('⏱ Timeout on [$domain]');
      } catch (e) {
        debugPrint('❌ Error [$domain]: $e');
      }
    }

    debugPrint('🚫 All domains failed (POST /subscription)');
    return null;
  }

  /// Get tak_links (GET /api/status)
  static Future<List<String>> getTakLinks() async {
    for (final domain in domainCandidates) {
      final url = domain.startsWith('http')
          ? '$domain/api/status'
          : 'https://$domain/api/status';

      debugPrint('🚀 GET: $url');

      try {
        final sw = Stopwatch()..start();
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        sw.stop();

        debugPrint(
          '📶 [$domain] in ${sw.elapsedMilliseconds}ms: ${response.statusCode}',
        );

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);

        if (data is Map && data['domains'] is List) {
          final newDomains = List<String>.from(data['domains']);
          if (!newDomains.contains('zurtex.net')) {
            newDomains.insert(0, 'zurtex.net');
          }

          domainCandidates
            ..clear()
            ..addAll(newDomains);

          debugPrint('🌐 Updated domains: $domainCandidates');
        }

        if (data['tak_links'] is List) {
          final links = List<String>.from(
            data['tak_links'],
          ).where((link) => link.startsWith('vless://')).toList();

          ApiConfig.baseUrl = domain;
          debugPrint('✅ Found ${links.length} tak_links');
          return links;
        } else {
          debugPrint('⚠️ No tak_links in [$domain]');
        }
      } on TimeoutException {
        debugPrint('⏱ Timeout [$domain]');
      } on HandshakeException {
        debugPrint('🔐 SSL Handshake failed [$domain]');
      } catch (e) {
        debugPrint('❌ General error [$domain]: $e');
      }
    }

    debugPrint('🚫 All domains failed (GET /status)');
    return [];
  }
}
