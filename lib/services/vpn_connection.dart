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
    String? customRemark, // Custom notification text
  }) async {
    // If customRemark is provided, modify the config URL to use it
    String modifiedConfigUrl = configUrl;
    if (customRemark != null) {
      // Replace the fragment (part after #) with the custom remark
      modifiedConfigUrl =
          configUrl.split('#')[0] + '#${Uri.encodeComponent(customRemark)}';
    }

    final parser = FlutterV2ray.parseFromURL(modifiedConfigUrl);
    final permissionGranted = await _v2ray.requestPermission();
    if (!permissionGranted) throw Exception("VPN permission not granted");

    await _v2ray.initializeV2Ray(); // Optional redundancy, safe to leave

    await _v2ray.startV2Ray(
      remark: parser.remark, // This will now use the modified remark from URL
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
