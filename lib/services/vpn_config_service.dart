import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zurtex/constants/api_config.dart';

class VpnConfigService {
  static final List<String> domainCandidates = [
    'zurtex.net', // ✅ Primary domain
    // Add backup domains here if needed, e.g.:
    // 'backup1.net',
    // 'backup2.net',
    // 'backup3.net',
  ];

  /// Tries each domain until one returns valid tak_links
  static Future<List<String>> fetchTakLinksFromBackend(
    String endpointPath,
  ) async {
    for (final domain in domainCandidates) {
      final apiUrl = domain.startsWith('http')
          ? '$domain$endpointPath'
          : 'https://$domain$endpointPath';

      debugPrint('🚀 Requesting: $apiUrl'); // ← ADD THIS LINE

      try {
        final sw = Stopwatch()..start();
        final response = await http
            .get(Uri.parse(apiUrl))
            .timeout(const Duration(seconds: 5));
        sw.stop();

        debugPrint(
          '📶 Response from [$domain] in ${sw.elapsedMilliseconds}ms: ${response.statusCode}',
        );
        debugPrint('📦 Raw body: ${response.body}');

        if (response.statusCode != 200) {
          debugPrint('❌ [$domain] returned ${response.statusCode}');
          continue;
        }

        final data = jsonDecode(response.body);

        // ✅ Update domain list if new ones are received
        if (data is Map && data['domains'] is List) {
          final newDomains = List<String>.from(data['domains']);

          if (!newDomains.contains('zurtex.net')) {
            newDomains.insert(0, 'zurtex.net');
          }

          domainCandidates
            ..clear()
            ..addAll(newDomains);

          debugPrint('🌐 Updated domain list: $domainCandidates');
        }

        // ✅ Return config links
        if (data['tak_links'] is List) {
          final links = List<String>.from(
            data['tak_links'],
          ).where((link) => link.startsWith('vless://')).toList();

          ApiConfig.baseUrl = domain;
          debugPrint(
            '✅ Found ${links.length} tak_links, using domain: $domain',
          );
          return links;
        } else {
          debugPrint('⚠️ No tak_links found in response from [$domain]');
        }
      } on TimeoutException {
        debugPrint('⏱ Timeout from [$domain]');
      } catch (e) {
        debugPrint('❌ Exception from [$domain]: $e');
        if (e is HandshakeException) {
          debugPrint('❗ SSL Handshake failed – check cert');
        }
      }
    }

    debugPrint('🚫 All domains failed to return valid tak_links');
    return [];
  }
}
