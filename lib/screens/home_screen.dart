// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zurtex/utils/toast_utils.dart';
import '../services/vpn_utils.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart'; // ✅ ADD THIS
import 'dart:async';
import '../services/vpn_link_service.dart';
import '../models/vpn_account.dart';
import '../widgets/top_curve_clipper.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../widgets/info_box.dart'; // adjust path based on your structure
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:country_ip/country_ip.dart';
import 'dart:ui';
import '../widgets/renewal_sheet.dart'; // adjust path if needed
import 'package:mobile_device_identifier/mobile_device_identifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> saveLastWorkingConfig(String config) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_working_config', config);
}

Future<String?> getLastWorkingConfig() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('last_working_config');
}

Future<String> getDeviceId() async {
  final deviceId = await MobileDeviceIdentifier().getDeviceId();
  if (deviceId == null || deviceId.isEmpty) {
    throw Exception("Failed to get device ID");
  }
  return deviceId;
}

Future<String?> getCachedUsername() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('lastVpnUsername');
}
// Widget getPingStatusDot(int? ping) {
//   if (ping == null) {
//     // still fetching
//     return LoadingAnimationWidget.beat(color: Color(0xFF56A6E7), size: 20);
//   }

//   if (ping == -1) {
//     // disconnected or failed
//     return Icon(Icons.circle, size: 25, color: Colors.red);
//   }

//   if (ping < 1000) {
//     return Icon(Icons.circle, size: 25, color: Colors.green);
//   } else if (ping < 3000) {
//     return Icon(Icons.circle, size: 25, color: Colors.yellow);
//   } else {
//     return Icon(Icons.circle, size: 25, color: Colors.red);
//   }
// }

const Map<String, String> countryCodeToPersian = {
  'US': 'آمریکا',
  'DE': 'آلمان',
  'FR': 'فرانسه',
  'IR': 'ایران',
  'CA': 'کانادا',
  'GB': 'انگلستان',
  'TR': 'ترکیه',
  'IN': 'هند',
  'AE': 'امارات',
  'JP': 'ژاپن',
  'NL': 'هلند',
  'IT': 'ایتالیا',
  'FI': 'فنلاند',
  // Add more as needed
};

const Map<String, String> countryLabelToCode = {
  'آلمان': 'de',
  'انگلستان': 'gb',
  'فرانسه': 'fr',
  'فنلاند': 'fi',
  'امارات': 'ae',
  'ایران': 'ir',
  'آمریکا': 'us',
  'ژاپن': 'jp',
  'ترکیه': 'tr',
  'هلند': 'nl',
  'کانادا': 'ca',
  'هند': 'in',
  'ارمنستان': 'am',
  'ایتالیا': "it",
  // Add more as needed
};

String? getCountryCodeFromLink(String link) {
  String label = getServerLabel(link).trim();

  // ✅ Remove anything inside parentheses like (HTTP+)
  label = label.replaceAll(RegExp(r'\(.*?\)'), '').trim();

  // ✅ Now match to your Persian-to-code map
  return countryLabelToCode[label];
}

Widget buildFlag(String? countryCode, {required String link}) {
  final label = Uri.decodeComponent(link.split('#').lastOrNull ?? '');
  final isEmergency = label.contains('اضطراری');

  final codeToShow = isEmergency ? 'ir' : (countryCode ?? 'ir');

  return ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: CachedNetworkImage(
      imageUrl: 'https://flagcdn.com/w40/$codeToShow.png',
      width: 33,
      height: 22,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          Container(width: 33, height: 22, color: const Color(0xFF404040)),
      errorWidget: (context, url, error) =>
          const Icon(Icons.flag_outlined, size: 18, color: Colors.white54),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<String> vpnConfigs = [];
  String? selectedDropdownOption = 'auto'; // user-selected item
  String? selectedConfig; // actual usable VLESS config
  bool isConnected = false;
  ValueNotifier<V2RayStatus> v2rayStatus = ValueNotifier(V2RayStatus());
  late final FlutterV2ray flutterV2ray;
  int? selectedServerPing;
  bool isFetchingPing = false;
  VpnAccount? account;
  String loadingMessage = 'در حال دریافت اطلاعات حساب برای این دستگاه';
  Map<String, int?> serverPings = {}; // link → delay in ms (nullable if failed)
  bool isCheckingConnection = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _dropdownOverlay;
  final ValueNotifier<bool> dropdownOpenNotifier = ValueNotifier(false);
  final GlobalKey _dropdownKey = GlobalKey();
  int failedChecks = 0;
  final int maxFailures = 3; // ✅ fixed
  late final FToast fToast;
  String? country =
      "ایران"; // or `late String country;` if you are sure it will be assigned before use
  int? ping;
  int currentTestingIndex = 0;
  String? subscriptionStatus;
  bool isAppActive = true; // ⬅️ Controls logic
  bool isFetchingIp = false;
  bool seemsDisconnected = false;
  bool shouldDisconnectAfterUpdate = false;
  String? username;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getCachedUsername().then((value) {
      setState(() {
        username = value;
      });
    });
    fToast = FToast();
    fToast.init(context);
    initializeVpnConfigs();

    // ✅ First, assign it
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        v2rayStatus.value = status;
      },
    );

    // ✅ Then call initializeV2Ray()
    flutterV2ray.initializeV2Ray();
    //startContinuousSelectedPing();
  }

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      return ''; // or return a placeholder
    }
  }

  void showRenewalSheet(
    BuildContext context, {
    required Function(VpnAccount) onReceiptSubmitted,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => RenewalSheet(
        onReceiptSubmitted: onReceiptSubmitted,
        account: account!,
      ),
    );
  }
  // Future<bool> checkInternetThroughProxy() async {
  //   try {
  //     final uri = Uri.parse(
  //       'https://www.google.com/generate_204',
  //     ); // fast, light
  //     final httpClient = HttpClient();

  //     httpClient.findProxy = (url) {
  //       return "PROXY 127.0.0.1:10809"; // FlutterV2Ray default local proxy
  //     };

  //     httpClient.badCertificateCallback =
  //         (X509Certificate cert, String host, int port) => true;

  //     final request = await httpClient.getUrl(uri);
  //     final response = await request.close();

  //     return response.statusCode == 204;
  //   } catch (e) {
  //     print('❌ Proxy test failed: $e');
  //     return false;
  //   }
  // }
  // Future<bool> checkInternet() async {
  //   const int maxAttempts = 3;

  //   for (int attempt = 1; attempt <= maxAttempts; attempt++) {
  //     try {
  //       final uri = Uri.parse('https://www.google.com/generate_204');
  //       final client = HttpClient();

  //       final request = await client
  //           .getUrl(uri)
  //           .timeout(const Duration(seconds: 2));
  //       final response = await request.close().timeout(
  //         const Duration(seconds: 2),
  //       );

  //       if (response.statusCode == 204) {
  //         return true; // ✅ success
  //       }
  //     } catch (_) {
  //       // 🔁 continue loop
  //     }
  //   }

  //   return false; // ❌ failed all attempts
  // }
  Widget buildServerProgressBar() {
    if (vpnConfigs.isEmpty) return const SizedBox.shrink();

    final total = (selectedDropdownOption == "auto")
        ? vpnConfigs.length *
              3 // 3 attempts per server
        : 3; // 3 attempts for single selected server

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.rtl,
      children: List.generate(total, (index) {
        final isActive = index >= currentTestingIndex;
        return Container(
          width: 6,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF56A6E7) : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Future<int?> checkInternetWithPing() async {
    if (!isAppActive) return null;

    const int maxAttempts = 3;
    const url = 'https://www.google.com/generate_204';

    // Create one Dio instance for this call.
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        // accept any status so we can handle it manually
        validateStatus: (_) => true,
      ),
    );

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!isAppActive) return null;

      try {
        final sw = Stopwatch()..start();

        final response = await dio.get(url);

        sw.stop();

        // Google returns 204 for success; accept 200 as fallback
        final ok = response.statusCode == 204 || response.statusCode == 200;
        if (ok) return sw.elapsedMilliseconds;

        debugPrint(
          '❌ Unexpected status code (${response.statusCode}) on attempt $attempt',
        );
      } on DioException catch (e) {
        setState(() => currentTestingIndex++);

        // Handle Dio-specific time-outs
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          debugPrint('⏱ Timeout on attempt $attempt');
        } else {
          debugPrint('❌ Dio error on attempt $attempt: $e');
        }
      } catch (e) {
        debugPrint('❌ Ping attempt $attempt failed: $e');
      }
    }
    return null; // All attempts failed
  }

  Future<bool> autoConnect() async {
    final savedConfig = await getLastWorkingConfig();

    // 1. Sort configs by ping (nulls at end)
    final sortedConfigs = [...vpnConfigs];
    sortedConfigs.sort((a, b) {
      final pingA = serverPings[a];
      final pingB = serverPings[b];

      if (pingA == null && pingB == null) return 0;
      if (pingA == null) return 1;
      if (pingB == null) return -1;
      return pingA.compareTo(pingB);
    });

    // 2. Prioritize last working config if present
    if (savedConfig != null && sortedConfigs.contains(savedConfig)) {
      sortedConfigs.remove(savedConfig);
      sortedConfigs.insert(0, savedConfig);
    }

    for (int i = 0; i < sortedConfigs.length; i++) {
      final config = sortedConfigs[i];
      final parser = FlutterV2ray.parseFromURL(config);

      final hasPermission = await flutterV2ray.requestPermission();
      if (!hasPermission) {
        return false;
      }

      await flutterV2ray.startV2Ray(
        remark: parser.remark,
        config: parser.getFullConfiguration(),
        proxyOnly: false,
      );

      await Future.delayed(const Duration(milliseconds: 1000));

      while (true) {
        if (v2rayStatus.value.state == 'CONNECTED') break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      ping = await checkInternetWithPing();
      if (ping != null) {
        await saveLastWorkingConfig(config); // ✅ Save successful config

        setState(() {
          selectedConfig = config;
          isConnected = true;
        });
        fetchCurrentIpInfo();
        return true;
      }

      // ❌ If connection fails, stop V2Ray and continue
      await flutterV2ray.stopV2Ray();
      await Future.delayed(const Duration(milliseconds: 1000));
      while (true) {
        if (v2rayStatus.value.state == 'DISCONNECTED') break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return false; // ❌ No successful connection
  }

  void fetchCurrentIpInfo([String? order]) async {
    await Future.delayed(
      const Duration(seconds: 1),
    ); // 1-second delay before running the function

    // if (order == "Reset") {
    //   setState(() {
    //     country = countryCodeToPersian["IR"];
    //   });
    //   return;
    // }

    setState(() {
      isFetchingIp = true;
    });

    final response = await CountryIp.find();

    if (response != null) {
      setState(() {
        country =
            countryCodeToPersian[response.countryCode] ?? response.country;
      });
    }

    setState(() {
      isFetchingIp = false;
    });
  }

  OverlayEntry _buildDropdownOverlay() {
    final RenderBox renderBox =
        _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy + renderBox.size.height,
        width: renderBox.size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, 70),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF303030),
                borderRadius: BorderRadius.circular(12),
              ),
              constraints: const BoxConstraints(maxHeight: 255),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  ListTile(
                    onTap: () {
                      setState(() {
                        selectedDropdownOption = 'auto';
                        selectedConfig = null;
                        selectedServerPing = null;
                      });
                      toggleDropdown();
                    },
                    title: const Center(
                      child: Text(
                        'اتصال به بهترین سرور',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                  ...vpnConfigs.map((config) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                      ), // 👈 30 total
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            selectedDropdownOption = config;
                            selectedConfig = config;
                            selectedServerPing = null;
                          });
                          toggleDropdown();
                        },
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          textDirection: TextDirection.ltr,
                          children: [
                            buildFlag(
                              getCountryCodeFromLink(config),
                              link: config,
                            ),
                            const SizedBox(width: 15),
                            Flexible(
                              child: Text(
                                getServerLabel(config),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                                textDirection: TextDirection.rtl,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void toggleDropdown() {
    if (dropdownOpenNotifier.value) {
      _dropdownOverlay?.remove();
      dropdownOpenNotifier.value = false;
    } else {
      _dropdownOverlay = _buildDropdownOverlay();
      Overlay.of(context).insert(_dropdownOverlay!);
      dropdownOpenNotifier.value = true;
    }
  }

  bool _monitoringConnection = false;

  void startConnectionMonitor() {
    if (_monitoringConnection) return;
    _monitoringConnection = true;

    () async {
      while (isConnected && _monitoringConnection) {
        final newPing = await checkInternetWithPing();
        final success = newPing != null;

        ping = newPing;

        if (!success && isAppActive) {
          failedChecks++;
        } else {
          failedChecks = 0;
          setState(() => seemsDisconnected = false);
        }

        if (failedChecks >= maxFailures) {
          seemsDisconnected = true;
        }

        // stop monitoring if V2Ray reports disconnected
        if (v2rayStatus.value.state == 'DISCONNECTED') {
          _monitoringConnection = false;
          await flutterV2ray.stopV2Ray();
          setState(() {
            isConnected = false;
            isCheckingConnection = false;
          });
          fetchCurrentIpInfo('Reset');
          break;
        }

        // wait 5 seconds before the next ping
        await Future.delayed(const Duration(seconds: 3));
      }
    }();
  }

  void stopConnectionMonitor() {
    _monitoringConnection = false;
  }

  // Future<void> getAllServerPingsOnce(List<String> configs) async {
  //   final results = <String, int?>{};

  //   for (int i = 0; i < configs.length; i++) {
  //     final link = configs[i];

  //     Future.delayed(Duration(milliseconds: i * 500), () async {
  //       try {
  //         final parser = FlutterV2ray.parseFromURL(link);
  //         final delay = await flutterV2ray
  //             .getServerDelay(config: parser.getFullConfiguration())
  //             .timeout(
  //               const Duration(seconds: 5),
  //               onTimeout: () {
  //                 debugPrint("⏱ Timeout while pinging $link");
  //                 return -1;
  //               },
  //             );

  //         results[link] = delay;
  //       } catch (e) {
  //         debugPrint("❌ Failed to ping $link: $e");
  //         results[link] = -1;
  //       }

  //       if (!mounted) return;

  //       // 🔄 Immediately update UI when this ping completes
  //       setState(() {
  //         serverPings = Map.from(results);
  //       });

  //       if (dropdownOpenNotifier.value) {
  //         _dropdownOverlay?.remove();
  //         _dropdownOverlay = _buildDropdownOverlay();
  //         Overlay.of(context).insert(_dropdownOverlay!);
  //       }
  //     });
  //   }
  // }

  // void startContinuousAllPings(List<String> configs) async {
  //   while (mounted && isAppActive) {
  //     // ✅ Skip pinging if already connected or in connection process
  //     if (isConnected || isCheckingConnection) {
  //       await Future.delayed(const Duration(seconds: 10));
  //       continue;
  //     }

  //     final results = <String, int?>{};

  //     await Future.wait(
  //       configs.map((link) async {
  //         try {
  //           final parser = FlutterV2ray.parseFromURL(link);
  //           final delay = await flutterV2ray
  //               .getServerDelay(config: parser.getFullConfiguration())
  //               .timeout(
  //                 const Duration(seconds: 5),
  //                 onTimeout: () {
  //                   debugPrint("⏱ Timeout while pinging $link");
  //                   return -1;
  //                 },
  //               );
  //           results[link] = delay;
  //         } catch (e) {
  //           debugPrint("❌ Failed to ping $link: $e");
  //           results[link] = -1;
  //         }
  //       }),
  //     );

  //     if (!mounted || !isAppActive) break;

  //     setState(() {
  //       serverPings = Map.from(results);
  //     });

  //     if (dropdownOpenNotifier.value) {
  //       _dropdownOverlay?.remove();
  //       _dropdownOverlay = _buildDropdownOverlay();
  //       Overlay.of(context).insert(_dropdownOverlay!);
  //     }

  //     await Future.delayed(const Duration(seconds: 10));
  //   }
  // }

  // void startContinuousSelectedPing() async {
  //   while (mounted) {
  //     if (selectedConfig == null) {
  //       await Future.delayed(Duration(milliseconds: 500));
  //       continue;
  //     }

  //     try {
  //       isFetchingPing = true;
  //       final parser = FlutterV2ray.parseFromURL(selectedConfig!);
  //       final fullConfig = parser.getFullConfiguration();
  //       final delay = await flutterV2ray
  //           .getServerDelay(config: fullConfig)
  //           .timeout(Duration(seconds: 3));

  //       if (!mounted) break;
  //       setState(() {
  //         selectedServerPing = delay;
  //       });
  //     } catch (e) {
  //       if (!mounted) break;

  //       setState(() {
  //         selectedServerPing = -1;
  //       });
  //     } finally {
  //       isFetchingPing = false;
  //     }

  //     // 🔁 Restart immediately — no delay
  //   }
  // }

  Future<void> initializeVpnConfigs() async {
    try {
      setState(() {
        loadingMessage = 'ارتباط با سرور';
      });

      final deviceId = await getDeviceId();

      final result = await VpnLinkService.getVpnAccount(deviceId);
      if (result == null) throw Exception('دریافت اطلاعات حساب ناموفق بود');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastVpnUsername', result.username);
      setState(() {
        account = result;
        subscriptionStatus = result.status; // ⬅️ No more `.onlineInfo?.status`
      });

      final links = result.takLinks; // ⬅️ Access directly
      final validConfigs = links.where((config) {
        final label = getServerLabel(config).trim();
        return label.isNotEmpty && label != 'Bad Config' && label != '..';
      }).toList();

      final newSelected = validConfigs.contains(selectedConfig)
          ? selectedConfig
          : (validConfigs.isNotEmpty ? validConfigs.first : null);
      if (newSelected != null) {
        final parser = FlutterV2ray.parseFromURL(newSelected);
        await resetVpnWithRealConfig(
          parser.getFullConfiguration(),
          'reset-step',
        );
      }
      //startContinuousAllPings(account?.takLinks ?? []);
      setState(() {
        vpnConfigs = validConfigs;
        selectedConfig = newSelected;
        //getAllServerPingsOnce(validConfigs); // fire-and-forget
      });
    } catch (e) {
      setState(() {
        loadingMessage = 'خطا در دریافت اطلاعات';
      });
    }
  }

  // String formatPing(int ping) {
  //   final str = ping.toString();
  //   return str.padLeft(4, '0');
  // }

  String convertToPersianNumber(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], persian[i]);
    }
    return input;
  }

  Future<void> resetVpnWithRealConfig(String config, String remark) async {
    if (v2rayStatus.value.state == 'CONNECTED') {
      // VPN is already active — just monitor it
      setState(() {
        isConnected = true;
      });
      startConnectionMonitor(); // ✅ Begin monitoring
      return;
    }

    try {
      await flutterV2ray.startV2Ray(
        remark: remark,
        config: config,
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );

      // ✅ Wait until it's connected
      while (v2rayStatus.value.state != 'CONNECTED') {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // ✅ Immediately stop to flush out other VPN apps
      await flutterV2ray.stopV2Ray();
      fetchCurrentIpInfo(); // 🧠 Refresh IP info, DNS, etc.
    } catch (e) {
      // Optionally log
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque, // Ensure taps outside are caught
            onTap: () {
              if (dropdownOpenNotifier.value) {
                _dropdownOverlay?.remove();
                dropdownOpenNotifier.value = false;
              }
            },
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          // background curved header
                          ClipPath(
                            clipper: TopCurveClipper(),
                            child: Container(
                              height: 155,
                              color: subscriptionStatus == 'expired'
                                  ? Colors.red
                                  : isConnected
                                  ? Colors.green
                                  : const Color(0xFF56A6E7),
                            ),
                          ),

                          // content above the curve
                          Column(
                            children: [
                              const SizedBox(height: 35),
                              Center(
                                child: const Text(
                                  'ZURTEX',
                                  style: TextStyle(
                                    fontFamily: 'Exo2',
                                    fontWeight:
                                        FontWeight.w700, // or w600 or normal
                                    fontSize: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ), // spacing from top
                              // other body content goes here...
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 5),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            InfoBox(
                              title: 'روز باقی‌مانده',
                              value: account?.remainingDays.toString() ?? '---',
                            ),
                            InfoBox(
                              title: 'حجم باقی‌مانده',
                              value:
                                  '${account?.remainingGB.toStringAsFixed(1) ?? '--'} GB',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 18),

                      // Dropdown
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // 🔽 Dropdown
                                CompositedTransformTarget(
                                  link: _layerLink,
                                  child: GestureDetector(
                                    key: _dropdownKey,
                                    onTap: () {
                                      if (isConnected || isCheckingConnection) {
                                        return; // 🔒 don't open dropdown if connected
                                      }
                                      toggleDropdown(); // 🔓 open if not connected
                                    },
                                    child: ValueListenableBuilder<bool>(
                                      valueListenable: dropdownOpenNotifier,
                                      builder: (context, isOpen, _) {
                                        return Container(
                                          width: 310,
                                          height: 65,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF303030),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 30,
                                                  ),
                                              child: isOpen
                                                  ? const Text(
                                                      'سروری را برای اتصال انتخاب کنید',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                      ),
                                                      textDirection:
                                                          TextDirection.rtl,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )
                                                  : isCheckingConnection
                                                  ? Row(
                                                      children: [
                                                        Expanded(
                                                          child:
                                                              buildServerProgressBar(), // ✅ your widget
                                                        ),
                                                      ],
                                                    )
                                                  : isConnected
                                                  ? Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 0,
                                                          ), // 30 padding on both sides
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        textDirection: TextDirection
                                                            .ltr, // RTL so flag is visually right
                                                        children: [
                                                          // Flag on far right (visually left)
                                                          buildFlag(
                                                            getCountryCodeFromLink(
                                                              selectedConfig ??
                                                                  '',
                                                            ),
                                                            link:
                                                                selectedConfig ??
                                                                '',
                                                          ),

                                                          // Ping or warning text on far left (visually right)
                                                          Expanded(
                                                            child: Text(
                                                              seemsDisconnected
                                                                  ? 'متصل نیستید'
                                                                  : 'پینگ ${ping ?? 'در حال دریافت'}',
                                                              style: TextStyle(
                                                                color:
                                                                    seemsDisconnected
                                                                    ? Colors.red
                                                                    : Colors
                                                                          .green,
                                                                fontSize: 18,
                                                              ),
                                                              textAlign: TextAlign
                                                                  .right, // align text right edge
                                                              textDirection:
                                                                  TextDirection
                                                                      .rtl,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              maxLines: 2,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : selectedDropdownOption ==
                                                        'auto'
                                                  ? const Text(
                                                      'اتصال به بهترین سرور',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                      ),
                                                      textDirection:
                                                          TextDirection.rtl,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )
                                                  : Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      textDirection: TextDirection
                                                          .ltr, // RTL for proper Persian layout
                                                      children: [
                                                        // 🏳️ Flag on far left (in RTL, this appears visually left)
                                                        buildFlag(
                                                          getCountryCodeFromLink(
                                                            selectedConfig ??
                                                                '',
                                                          ),
                                                          link:
                                                              selectedConfig ??
                                                              '',
                                                        ),

                                                        // 📦 Server label on the right
                                                        Flexible(
                                                          child: Text(
                                                            getServerLabel(
                                                              selectedConfig ??
                                                                  '',
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 18,
                                                                ),
                                                            textDirection:
                                                                TextDirection
                                                                    .rtl,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 18),
                            Center(
                              child: GestureDetector(
                                onTap: () async {
                                  currentTestingIndex = 0;

                                  if (subscriptionStatus == 'expired') {
                                    showMyToast(
                                      "لطفاً از دکمه تمدید استفاده کنید",
                                      context,
                                      backgroundColor: Colors.red,
                                    );

                                    return;
                                  }

                                  if (!isCheckingConnection) {
                                    if (!isConnected) {
                                      setState(() {
                                        isCheckingConnection = true;
                                      });

                                      bool success = false;
                                      final currentContext = context;

                                      // ✅ AUTO CONNECT
                                      if (selectedDropdownOption == "auto") {
                                        success = await autoConnect();
                                      }
                                      // ✅ CONNECT TO SELECTED CONFIG
                                      else {
                                        final parser =
                                            FlutterV2ray.parseFromURL(
                                              selectedConfig!,
                                            );

                                        final hasPermission = await flutterV2ray
                                            .requestPermission();
                                        if (!hasPermission) {
                                          setState(
                                            () => isCheckingConnection = false,
                                          );
                                          return;
                                        }

                                        await flutterV2ray.startV2Ray(
                                          remark: parser.remark,
                                          config: parser.getFullConfiguration(),
                                          proxyOnly: false,
                                        );
                                        const Duration(milliseconds: 1000);

                                        // wait until V2Ray reports CONNECTED
                                        while (true) {
                                          final status = v2rayStatus.value;
                                          if (status.state == 'CONNECTED') {
                                            break;
                                          }
                                          await Future.delayed(
                                            const Duration(milliseconds: 100),
                                          );
                                        }

                                        ping = await checkInternetWithPing();
                                        if (ping != null) {
                                          success = true;
                                        }
                                      }

                                      if (success) {
                                        setState(() {
                                          isConnected = true;
                                          isCheckingConnection = false;
                                        });

                                        startConnectionMonitor();
                                        fetchCurrentIpInfo();

                                        // ✅ Save selectedConfig if it's not null
                                        if (selectedConfig != null) {
                                          final prefs =
                                              await SharedPreferences.getInstance();
                                          await prefs.setString(
                                            'last_working_config',
                                            selectedConfig!,
                                          );
                                        }
                                      } else {
                                        if (selectedDropdownOption == "auto") {
                                          if (mounted) {
                                            showMyToast(
                                              "هیچ سروری متصل نشد. لطفا سرور ها را بازرسانی کرده یا با پشتیبانی تماس بگیرید.",
                                              currentContext,
                                              backgroundColor: Colors.red,
                                            );
                                          }
                                        } else {
                                          if (mounted) {
                                            showMyToast(
                                              "اتصال برقرار نشد. لطفا سرور دیگری انتخاب کنید.",
                                              currentContext,
                                              backgroundColor: Colors.red,
                                            );
                                          }
                                        }

                                        await flutterV2ray.stopV2Ray();

                                        setState(() {
                                          isConnected = false;
                                          isCheckingConnection = false;
                                        });
                                        fetchCurrentIpInfo();
                                      }
                                    }
                                    // 🔴 Already connected → disconnect
                                    else {
                                      await flutterV2ray.stopV2Ray();
                                      stopConnectionMonitor();

                                      setState(() {
                                        isConnected = false;
                                      });
                                      fetchCurrentIpInfo("Reset");
                                    }
                                  }
                                },
                                child: Container(
                                  width: 310,
                                  height: 65,
                                  decoration: BoxDecoration(
                                    color: subscriptionStatus == 'expired'
                                        ? Colors.red
                                        : (isConnected
                                              ? Colors.green
                                              : const Color(0xFF56A6E7)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: isCheckingConnection
                                        ? LoadingAnimationWidget.threeArchedCircle(
                                            color: Colors.white,
                                            size: 30,
                                          )
                                        : Text(
                                            isConnected ? 'قطع اتصال' : 'اتصال',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 18),

                            Center(
                              child: SizedBox(
                                width: double
                                    .infinity, // 💡 Force full screen width
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .center, // ✅ center the children inside
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        // ✅ No pending — proceed to show the renewal sheet
                                        showRenewalSheet(
                                          context,
                                          onReceiptSubmitted: (updatedAccount) {
                                            setState(() {
                                              account = updatedAccount;
                                            });
                                          },
                                        );
                                      },
                                      child: Container(
                                        width: 150,
                                        height: 65,
                                        decoration: BoxDecoration(
                                          color: subscriptionStatus == 'expired'
                                              ? Colors.red
                                              : isConnected
                                              ? Colors.green
                                              : const Color(0xFF56A6E7),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            "تمدید",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    GestureDetector(
                                      onTap: () {
                                        if (!isFetchingIp) {
                                          fetchCurrentIpInfo(); // ✅ Refresh IP
                                        }
                                      },
                                      child: Center(
                                        child: Container(
                                          width: 150,
                                          height: 65,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF303030),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Center(
                                            child: isFetchingIp
                                                ? LoadingAnimationWidget.threeArchedCircle(
                                                    color: Colors.white,
                                                    size: 30,
                                                  )
                                                : Text(
                                                    "آی پی $country",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 90),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 📞 Support
                      GestureDetector(
                        onTap: () {
                          launchUrl(Uri.parse('https://t.me/Zurtexapp'));
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/Support.png',
                              width: 50,
                              height: 50,
                            ),
                            // const SizedBox(height: 15),
                            // const Text(
                            //   'پشتیبانی',
                            //   style: TextStyle(
                            //     color: Colors.white,
                            //     fontSize: 14,
                            //   ),
                            //   textDirection: TextDirection.rtl,
                            // ),
                          ],
                        ),
                      ),

                      // 🔄 Refresh
                      GestureDetector(
                        onTap: () async {
                          vpnConfigs.clear();
                          await initializeVpnConfigs();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/refresh.png',
                              width: 50,
                              height: 50,
                            ),
                            // const SizedBox(height: 15),
                            // Text(
                            //   'بازآوری',
                            //   style: TextStyle(
                            //     color: Colors.white,
                            //     fontSize: 14,
                            //   ),
                            //   textDirection: TextDirection.rtl,
                            // ),
                          ],
                        ),
                      ),

                      // 📣 Channel
                      GestureDetector(
                        onTap: () {
                          launchUrl(Uri.parse('https://t.me/ZurtexV2rayApp'));
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/Telegram.png',
                              width: 50,
                              height: 50,
                            ),
                            // const SizedBox(height: 15),
                            // const Text(
                            //   'کانال',
                            //   style: TextStyle(
                            //     color: Colors.white,
                            //     fontSize: 14,
                            //   ),
                            //   textDirection: TextDirection.rtl,
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                GestureDetector(
                  onTap: () {
                    final username = account?.username;
                    if (username != null) {
                      Clipboard.setData(ClipboardData(text: username));
                    }
                  },
                  child: FutureBuilder<String>(
                    future: _getAppVersion(),
                    builder: (context, snapshot) {
                      final version = snapshot.data ?? '';
                      final user = account?.username ?? '---';
                      return Text(
                        'V$version  $user',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (vpnConfigs.isEmpty)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
                child: Container(
                  color: const Color(0xFF303030).withAlpha(50),
                  child: Stack(
                    children: [
                      // Centered ZURTEX content
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'ZURTEX',
                              style: TextStyle(
                                fontFamily: 'Exo2',
                                fontWeight: FontWeight.w700,
                                fontSize: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 50,
                              ),
                              child: Text(
                                loadingMessage,
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 30),
                            loadingMessage == 'خطا در دریافت اطلاعات'
                                ? const SizedBox.shrink() // shows nothing
                                : LoadingAnimationWidget.threeArchedCircle(
                                    color: Colors.white,
                                    size: 50,
                                  ),
                          ],
                        ),
                      ),

                      // Bottom actions
                      if (loadingMessage == 'خطا در دریافت اطلاعات')
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // 📞 Support
                                    GestureDetector(
                                      onTap: () {
                                        launchUrl(
                                          Uri.parse('https://t.me/Zurtexapp'),
                                        );
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            'assets/images/Support.png',
                                            width: 50,
                                            height: 50,
                                          ),
                                          const SizedBox(height: 15),
                                          const Text(
                                            'پشتیبانی',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 🔄 Refresh
                                    GestureDetector(
                                      onTap: () async {
                                        vpnConfigs.clear();
                                        await initializeVpnConfigs();
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            'assets/images/refresh.png',
                                            width: 50,
                                            height: 50,
                                          ),
                                          const SizedBox(height: 15),
                                          const Text(
                                            'تلاش دوباره',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 📣 Channel
                                    GestureDetector(
                                      onTap: () {
                                        launchUrl(
                                          Uri.parse(
                                            'https://t.me/ZurtexV2rayApp',
                                          ),
                                        );
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            'assets/images/Telegram.png',
                                            width: 50,
                                            height: 50,
                                          ),
                                          const SizedBox(height: 15),
                                          const Text(
                                            'کانال',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ✅ اتصال امن
                                    GestureDetector(
                                      onTap: () async {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        final savedConfig = prefs.getString(
                                          'lastConnectedConfig',
                                        );

                                        const fallbackConfig =
                                            'vless://b7d9fe60-132b-4eed-982e-04f792fe7008@g11.ratrat.xyz:2032?encryption=none&security=none&type=tcp&headerType=none#%40RatMosh_BOT%20g11-611650498-78512';

                                        final isFallback =
                                            savedConfig == null ||
                                            savedConfig.isEmpty;
                                        final configToUse = isFallback
                                            ? fallbackConfig
                                            : savedConfig;

                                        if (isFallback) {
                                          shouldDisconnectAfterUpdate = true;
                                        }

                                        final parser =
                                            FlutterV2ray.parseFromURL(
                                              configToUse,
                                            );
                                        await flutterV2ray.startV2Ray(
                                          remark: parser.remark,
                                          config: parser.getFullConfiguration(),
                                          proxyOnly: false,
                                        );

                                        vpnConfigs.clear();
                                        await initializeVpnConfigs();

                                        if (shouldDisconnectAfterUpdate) {
                                          await flutterV2ray.stopV2Ray();
                                          shouldDisconnectAfterUpdate = false;
                                        }
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            'assets/images/secure.png',
                                            width: 50,
                                            height: 50,
                                          ),
                                          const SizedBox(height: 15),
                                          const Text(
                                            'اتصال امن',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            textDirection: TextDirection.rtl,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),

                              GestureDetector(
                                onTap: () {
                                  final usernameText =
                                      account?.username ?? username;
                                  if (usernameText != null) {
                                    Clipboard.setData(
                                      ClipboardData(text: usernameText),
                                    );
                                  }
                                },
                                child: FutureBuilder<String>(
                                  future: _getAppVersion(),
                                  builder: (context, snapshot) {
                                    final version = snapshot.data ?? '';
                                    final user = account?.username ?? username;
                                    return Text(
                                      'V$version  $user',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                      textDirection: TextDirection.rtl,
                                      textAlign: TextAlign.center,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    stopConnectionMonitor(); // ✅ clean up

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      isAppActive = state == AppLifecycleState.resumed;
    });
  }
}
