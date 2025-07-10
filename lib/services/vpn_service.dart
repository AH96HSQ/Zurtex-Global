import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_account.dart';
import 'vpn_connection.dart';

class VpnService {
  static int totalAttempts = 1;
  static double step = 360;

  static List<String> domainCandidates = [
    '45.138.132.39:4000',
    'zurtexbackend569827.xyz',
  ];

  static const String backupVpnConfig =
      'vless://5c686fdf-7df3-4723-ac75-fa225edd8865@45.136.5.30:700?encryption=none&security=none&type=tcp&headerType=http#Emergency%20Zurtex%20Connection';

  static Future<VpnAccount?> getVpnAccount(
    String deviceId,
    ValueNotifier<double> progressNotifier,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0',
          'Accept': '*/*',
        },
      ),
    );

    totalAttempts = domainCandidates.length * 2;
    step = 360 / totalAttempts;
    progressNotifier.value = 360;

    for (final domain in domainCandidates) {
      final url = 'http://$domain/api/subscription';

      // 🔹 1. Try direct connection
      debugPrint('🔍 [Direct] Trying: $url');
      try {
        final response = await dio.post(
          url,
          queryParameters: {'_ts': DateTime.now().millisecondsSinceEpoch},
          data: {'deviceId': deviceId},
        );

        if (response.statusCode == 200) {
          final account = VpnAccount.fromJson(response.data);
          await prefs.setString('last_working_domain', domain);
          debugPrint('✅ [Direct] Success from [$domain]');
          progressNotifier.value = 0;
          return account;
        }
      } catch (e) {
        debugPrint('❌ [Direct] Failed from [$domain]: $e');
      }

      progressNotifier.value -= step;

      // 🔹 2. Try with VPN
      try {
        debugPrint('🔁 Connecting VPN for [$domain]...');
        await VpnConnection.connect(backupVpnConfig);
        await Future.delayed(const Duration(seconds: 3));

        debugPrint('🔍 [VPN] Retrying: $url');
        final vpnResponse = await dio.post(
          url,
          queryParameters: {'_ts': DateTime.now().millisecondsSinceEpoch},
          data: {'deviceId': deviceId},
        );

        if (vpnResponse.statusCode == 200) {
          final account = VpnAccount.fromJson(vpnResponse.data);
          await prefs.setString('last_working_domain', domain);
          debugPrint('✅ [VPN] Success from [$domain]');
          await VpnConnection.disconnect();
          progressNotifier.value = 0;
          return account;
        } else {
          debugPrint(
            '❌ [VPN] Failed from [$domain]: ${vpnResponse.statusCode}',
          );
        }
      } catch (e) {
        debugPrint('❌ [VPN] Exception from [$domain]: $e');
      } finally {
        debugPrint('🛑 Disconnecting VPN...');
        await VpnConnection.disconnect();
      }

      progressNotifier.value -= step;
      await Future.delayed(const Duration(seconds: 1));
    }

    progressNotifier.value = 0;
    debugPrint('❌❌ All per-domain connection attempts failed.');
    return null;
  }
}
