import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

class VpnConnection {
  static final ValueNotifier<V2RayStatus> status = ValueNotifier(V2RayStatus());
  static final FlutterV2ray _v2ray = FlutterV2ray(
    onStatusChanged: (newStatus) {
      status.value = newStatus;
      debugPrint("🔄 VPN Status changed: ${newStatus.state}");
    },
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await _v2ray.initializeV2Ray();
    _initialized = true;
  }

  static Future<void> connect(
    String configUrl, {
    bool proxyOnly = false,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
  }) async {
    final parser = FlutterV2ray.parseFromURL(configUrl);
    final permissionGranted = await _v2ray.requestPermission();
    if (!permissionGranted) throw Exception("VPN permission not granted");

    await _v2ray.initializeV2Ray(); // Optional redundancy, safe to leave

    await _v2ray.startV2Ray(
      remark: parser.remark,
      config: parser.getFullConfiguration(),
      proxyOnly: proxyOnly,
      blockedApps: blockedApps,
      bypassSubnets: bypassSubnets,
    );

    for (int i = 0; i < 80; i++) {
      if (status.value.state == 'CONNECTED') return;
      await Future.delayed(const Duration(milliseconds: 250));
    }

    throw Exception("VPN connection timeout");
  }

  static Future<void> disconnect() async {
    await _v2ray.stopV2Ray();
  }
}
