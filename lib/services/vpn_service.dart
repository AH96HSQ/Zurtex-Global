import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../models/vpn_account.dart';

class VpnService {
  static final ValueNotifier<V2RayStatus> v2rayStatus = ValueNotifier(
    V2RayStatus(),
  );

  static final FlutterV2ray flutterV2ray = FlutterV2ray(
    onStatusChanged: (status) {
      debugPrint('VPN status changed: ${status.state}');
      v2rayStatus.value = status; // 🔁 update the notifier
    },
  );

  static List<String> domainCandidates = ['5.78.94.88:5000'];

  static const String backupVpnConfig =
      'vless://5c686fdf-7df3-4723-ac75-fa225edd8865@zurtexbackend198267.xyz:700?encryption=none&security=none&type=tcp&headerType=http#🇹🇷 Turkey Zurtex';

  static Future<void> startVpn(String configString) async {
    final parser = FlutterV2ray.parseFromURL(configString);
    final permissionGranted = await flutterV2ray.requestPermission();

    if (!permissionGranted) throw Exception('VPN permission not granted');

    await flutterV2ray.startV2Ray(
      remark: parser.remark,
      config: parser.getFullConfiguration(),
      proxyOnly: false,
    );

    for (int i = 0; i < 40; i++) {
      final status = v2rayStatus.value;
      if (status.state == 'CONNECTED') return;
      await Future.delayed(const Duration(milliseconds: 250));
    }

    throw Exception('VPN connection timeout');
  }

  static Future<VpnAccount?> getVpnAccount(
    String deviceId,
    ValueNotifier<double> progressNotifier,
  ) async {
    final int totalAttempts = domainCandidates.length;
    final double step = 360 / totalAttempts;
    progressNotifier.value = 360;

    final prefs = await SharedPreferences.getInstance();
    bool shouldRetryWithVpn = false;

    for (final domain in domainCandidates) {
      final url = Uri.parse('http://$domain/api/subscription');
      debugPrint('🌐 Trying subscription from: $url');

      try {
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'Mozilla/5.0',
                'Accept': '*/*',
              },
              body: jsonEncode({'deviceId': deviceId}),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final account = VpnAccount.fromJson(data);
          await prefs.setString('last_working_domain', domain);
          debugPrint('✅ Subscription successful from [$domain]');
          progressNotifier.value = 0;
          return account;
        }
      } catch (e) {
        debugPrint('❌ Error connecting to [$domain]: $e');
        shouldRetryWithVpn = true;
      }

      progressNotifier.value -= step;
      await Future.delayed(const Duration(seconds: 2));
    }

    // Retry with VPN
    if (shouldRetryWithVpn) {
      try {
        debugPrint('🔄 Retrying with VPN...');
        await startVpn(backupVpnConfig);

        final account = await getVpnAccount(deviceId, progressNotifier);

        debugPrint('🛑 Stopping VPN after retry...');
        await flutterV2ray.stopV2Ray();

        return account;
      } catch (e) {
        debugPrint('❌ VPN retry failed: $e');
        await flutterV2ray
            .stopV2Ray(); // make sure VPN is stopped even on error
      }
    }

    progressNotifier.value = 0;
    debugPrint('❌❌ All connection attempts failed.');
    return null;
  }
}
