import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_account.dart';
import 'app_config.dart';
import 'auth_service.dart';

class VpnService {
  static int totalAttempts = 1;
  static double step = 360;

  static List<String> get domainCandidates => AppConfig.domainCandidates;
  static List<String> finalDomainList = [];

  static Future<VpnAccount?> getVpnAccount(
    ValueNotifier<double> progressNotifier,
    Future<void> Function() resetVpnCallback, {
    bool onlyCheckFirstDomain = false, // 👈 New optional mode flag
  }) async {
    // Get user email from authentication service
    final email = await AuthService.getUserEmail();
    if (email == null || email.isEmpty) {
      debugPrint('❌ No user email found. User must be logged in.');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();

    final savedDomain = prefs.getString('serversentdomain');

    final Set<String> uniqueDomains = {
      if (savedDomain != null) savedDomain,
      ...domainCandidates,
    };
    finalDomainList = uniqueDomains.toList();

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

    // 👇 Use 1 or all depending on the mode
    totalAttempts = onlyCheckFirstDomain ? 1 : finalDomainList.length * 2;
    step = 360 / totalAttempts;
    progressNotifier.value = 360;

    Future<VpnAccount?> tryDomains(String label) async {
      final domainsToTry = onlyCheckFirstDomain
          ? [finalDomainList.first] // 👈 Only try first
          : finalDomainList;

      for (final domain in domainsToTry) {
        final url = '$domain/api/subscription';
        debugPrint('🔍 [$label] Trying: $url');
        try {
          final response = await dio.post(
            url,
            queryParameters: {'_ts': DateTime.now().millisecondsSinceEpoch},
            data: {'email': email}, // ✅ Changed from deviceId to email
          );

          if (response.statusCode == 200) {
            final account = VpnAccount.fromJson(response.data);
            await prefs.setString('last_working_domain', domain);
            debugPrint('✅ [$label] Success from [$domain]');
            progressNotifier.value = 0;
            return account;
          }
        } catch (e) {
          debugPrint('❌ [$label] Failed from [$domain]: $e');
        }

        progressNotifier.value -= step;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return null;
    }

    // 🔹 Phase 1
    final firstTry = await tryDomains('Direct');
    if (firstTry != null || onlyCheckFirstDomain) return firstTry;

    // 🔹 Phase 2 (skip if only checking first)
    debugPrint('🔁 Calling resetVpnWithRealConfig...');
    await resetVpnCallback();

    final secondTry = await tryDomains('AfterVPNReset');
    if (secondTry != null) return secondTry;

    progressNotifier.value = 0;
    debugPrint('❌❌ All connection attempts failed.');
    return null;
  }
}
