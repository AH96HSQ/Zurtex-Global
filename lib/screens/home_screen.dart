// ignore_for_file: use_build_context_synchronously
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zurtex/services/vpn_connection.dart';
import 'package:zurtex/services/vpn_service.dart';
import 'package:zurtex/services/auth_service.dart';
import 'package:zurtex/utils/toast_utils.dart';
import 'package:zurtex/widgets/loading.dart';
import 'package:zurtex/widgets/pulsating_update.dart';
import '../services/vpn_utils.dart';
import 'dart:async';
import '../models/vpn_account.dart';
import '../widgets/top_curve_clipper.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:ui';
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

Future<String?> getCachedUsername() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('lastVpnUsername');
}
// Widget getPingStatusDot(int? ping) {
//   if (ping == null) {
//     // still fetching
//     return LoadingAnimationWidget.beat(color: Color(0xFF9700FF), size: 20);
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
  // ISO codes
  'US': 'آمریکا',
  'DE': 'آلمان',
  'FR': 'فرانسه',
  'IR': 'ایران',
  'CA': 'کانادا',
  'GB': 'انگلستان',
  'UK': 'انگلستان',
  'TR': 'ترکیه',
  'AE': 'امارات',
  'JP': 'ژاپن',
  'NL': 'هلند',
  'IT': 'ایتالیا',
  'FI': 'فنلاند',
  'PE': 'پرو',
  'RU': 'روسیه',
  'CN': 'چین',
  'IN': 'هند',
  'BR': 'برزیل',
  'ES': 'اسپانیا',
  'SE': 'سوئد',
  'CH': 'سوئیس',
  'AU': 'استرالیا',
  'AT': 'اتریش',
  'SG': 'سنگاپور',
  'KR': 'کره جنوبی',
  'KZ': 'قزاقستان',
  'UA': 'اوکراین',
  'PL': 'لهستان',
  'AR': 'آرژانتین',
  'MX': 'مکزیک',
  'SA': 'عربستان',
  'IQ': 'عراق',
  'SY': 'سوریه',
  'QA': 'قطر',

  // Optional English spellings (fallbacks)
  'Germany': 'آلمان',
  'France': 'فرانسه',
  'Iran': 'ایران',
  'United States': 'آمریکا',
  'Canada': 'کانادا',
  'United Kingdom': 'انگلستان',
  'Turkey': 'ترکیه',
  'Japan': 'ژاپن',
  'Netherlands': 'هلند',
  'The Netherlands': 'هلند',

  'Italy': 'ایتالیا',
  'Finland': 'فنلاند',
  'Peru': 'پرو',
  'Russia': 'روسیه',
  'China': 'چین',
  'India': 'هند',
  'Brazil': 'برزیل',
  'Spain': 'اسپانیا',
  'Sweden': 'سوئد',
  'Switzerland': 'سوئیس',
  'Australia': 'استرالیا',
  'Austria': 'اتریش',
  'Singapore': 'سنگاپور',
  'South Korea': 'کره جنوبی',
  'Kazakhstan': 'قزاقستان',
  'Ukraine': 'اوکراین',
  'Poland': 'لهستان',
  'Argentina': 'آرژانتین',
  'Mexico': 'مکزیک',
  'Saudi Arabia': 'عربستان',
  'Iraq': 'عراق',
  'Syria': 'سوریه',
  'Qatar': 'قطر',
};

const Map<String, String> countryLabelToCode = {
  'Germany': 'de',
  'UK': 'gb',
  'France': 'fr',
  'Finland': 'fi',
  'UAE': 'ae',
  'Iran': 'ir',
  'USA': 'us',
  'Japan': 'jp',
  'Turkey': 'tr',
  'Netherlands': 'nl',
  'Canada': 'ca',
  'India': 'in',
  'Armenia': 'am',
  'Italy': 'it',
  'Peru': 'pe',
  'Singapore': 'sg',
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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List<String> vpnConfigs = [];
  String? selectedConfig;
  String? selectedDropdownOption = 'auto'; // user-selected item
  bool isConnected = false;
  final currentStatus = VpnConnection.status.value;
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
  final ValueNotifier<double> progressNotifier = ValueNotifier(360);
  late final String rawLabel;
  late final String staticIranConfig;
  bool cancelRequested = false;
  bool hasCachedAccount = true;
  // late AnimationController _arrowPulseController;
  bool cameFromSaved = false;
  bool isFetchingVpnConfig = false;
  int _selectedPageIndex = 0; // Navigation bar state

  @override
  void initState() {
    super.initState();
    // _arrowPulseController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 300),
    //   lowerBound: 1.0,
    //   upperBound: 1.06,
    // )..repeat(reverse: true);
    _initAsyncThings();
    _loadSelectedDropdownOption();
    // initializeVpnState();
    checkCachedAccount();
    // loadVpnConfigFromCache();

    rawLabel = '🇮🇷 Iran - Zurtex';
    staticIranConfig =
        'vless://cde304d3-37f5-4f3c-aea5-de73a9305078@zurtexbackend256934.xyz:8443'
        '?encryption=none&security=tls&type=ws&host=zurtexbackend256934.xyz&path=%2Fzurtex'
        '#${Uri.encodeComponent(rawLabel)}';

    selectedConfig = staticIranConfig; // ✅ initialize here
    WidgetsBinding.instance.addObserver(this);
    getCachedUsername().then((value) {
      setState(() {
        username = value;
      });
    });
    fToast = FToast();
    fToast.init(context);
    initializeVpnConfigs();
  }

  Future<void> _initAsyncThings() async {
    await initializeVpnState();
    await resetVpnWithRealConfig(staticIranConfig, 'cached-resume');
    await loadVpnConfigFromCache(); // or anything else
    // ✅ Start VPN from saved static config
  }

  Future<void> initializeVpnState() async {
    await VpnConnection.initialize();
  }

  Future<void> loadVpnConfigFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('cachedAccount');

    if (json != null) {
      try {
        final cached = VpnAccount.fromJson(jsonDecode(json));
        final configs = [...cached.takLinks, staticIranConfig];
        final savedOption = prefs.getString('selectedDropdownOption');

        setState(() {
          cameFromSaved = true;
          account = cached;
          vpnConfigs = configs;
          selectedDropdownOption = savedOption ?? 'auto';
          selectedConfig = savedOption;
          subscriptionStatus = cached.status;
          hasCachedAccount = true;
        });
      } catch (e) {
        debugPrint('⚠️ Failed to resume from cached account: $e');
      }
    }
  }

  void checkCachedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('cachedAccount');
    if (json != null) {
      setState(() {
        hasCachedAccount = true;
      });
    } else {
      setState(() {
        hasCachedAccount = false;
      });
    }
  }

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      return ''; // or return a placeholder
    }
  }

  Future<void> _finalizeVpnAccount(VpnAccount result) async {
    final prefs = await SharedPreferences.getInstance();

    final filteredTakLinks = result.takLinks.where((config) {
      final label = getServerLabel(config).trim();
      return label.isNotEmpty && label != 'Bad Config' && label != '..';
    }).toList();

    final cleanedResult = VpnAccount(
      username: result.username,
      test: result.test,
      expiryTime: result.expiryTime,
      gigBytes: result.gigBytes,
      status: result.status,
      takLinks: filteredTakLinks,
      hasPendingReceipt: result.hasPendingReceipt,
      messages: result.messages,
      latestVersion: result.latestVersion,
      updateUrl: result.updateUrl,
      currentDomain: result.currentDomain,
    );

    await prefs.setString('lastVpnUsername', cleanedResult.username);
    await prefs.setString('cachedAccount', jsonEncode(cleanedResult.toJson()));

    if (cleanedResult.currentDomain != null) {
      await prefs.setString('serversentdomain', cleanedResult.currentDomain!);
    }

    setState(() {
      account = cleanedResult;
      subscriptionStatus = cleanedResult.status;
    });

    final links = [...filteredTakLinks, staticIranConfig];

    final validConfigs = links.where((config) {
      final label = getServerLabel(config).trim();
      return label.isNotEmpty && label != 'Bad Config' && label != '..';
    }).toList();

    final newSelected = validConfigs.contains(selectedConfig)
        ? selectedConfig
        : (validConfigs.isNotEmpty ? validConfigs.first : null);

    if (newSelected != null) {
      await resetVpnWithRealConfig(newSelected, 'reset-step');
    }

    setState(() {
      vpnConfigs = validConfigs;
      selectedConfig = newSelected;
    });
  }

  void _loadSelectedDropdownOption() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOption = prefs.getString('selectedDropdownOption');

    if (savedOption != null && savedOption.isNotEmpty) {
      setState(() {
        selectedDropdownOption = savedOption;
        selectedConfig = savedOption; // optional: if you want both
      });
    }
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
        ? (vpnConfigs.length - 1) *
              3 // 3 attempts per server
        : 3;

    final currentStep = (total - currentTestingIndex).clamp(0, total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      child: StepProgressIndicator(
        totalSteps: total,
        currentStep: currentStep,
        size: 31,
        padding: 2,
        selectedColor: const Color(0xFF9700FF),
        unselectedColor: Colors.grey.shade800,
        roundedEdges: const Radius.circular(7),
      ),
    );
  }

  Future<int?> checkInternetWithPing({
    bool useIranianSite = false,
    bool pingOnly = false, // ✅ New parameter
  }) async {
    if (!isAppActive && isConnected) return null;

    const int maxAttempts = 3;

    final String url = pingOnly
        ? 'http://clients3.google.com/generate_204' // ✅ Google lightweight ping
        : useIranianSite
        ? 'https://rubika.ir'
        : 'https://api64.ipify.org';

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
        validateStatus: (_) => true, // Accept all statuses
      ),
    );

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (cancelRequested) return null;
      if (!isAppActive && isConnected) return null;

      try {
        final stopwatch = Stopwatch()..start();
        debugPrint('🌐 Trying to connect to $url');

        final response = await dio.get(url);
        stopwatch.stop();

        final isSuccess =
            response.statusCode == 200 || response.statusCode == 204;

        if (isSuccess) {
          return stopwatch.elapsedMilliseconds;
        } else {
          debugPrint(
            '❌ Unexpected status code (${response.statusCode}) on attempt $attempt',
          );
        }
      } on DioException catch (e) {
        setState(() => currentTestingIndex++);

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          debugPrint('⏱ Timeout on attempt $attempt');
        } else {
          debugPrint('❌ Dio error on attempt $attempt: ${e.message}');
        }
      } catch (e) {
        debugPrint('❌ General error on attempt $attempt: $e');
      }
    }

    return null; // All attempts failed
  }

  Future<bool> autoConnect() async {
    final savedConfig = await getLastWorkingConfig();

    // 1. Sort configs by ping (nulls at end) — disabled for now
    final sortedConfigs = [...vpnConfigs];
    /*
  sortedConfigs.sort((a, b) {
    final pingA = serverPings[a];
    final pingB = serverPings[b];

    if (pingA == null && pingB == null) return 0;
    if (pingA == null) return 1;
    if (pingB == null) return -1;
    return pingA.compareTo(pingB);
  });
  */

    // 2. Exclude Iran configs
    sortedConfigs.removeWhere((c) => getServerLabel(c).contains('ایران'));

    // 3. Prioritize last working config if present
    if (savedConfig != null && sortedConfigs.contains(savedConfig)) {
      sortedConfigs.remove(savedConfig);
      sortedConfigs.insert(0, savedConfig);
    }

    // 4. Always prioritize هلند server
    final hollandIndex = sortedConfigs.indexWhere(
      (c) => getServerLabel(c).contains('هلند'),
    );

    if (hollandIndex != -1) {
      final hollandConfig = sortedConfigs.removeAt(hollandIndex);
      sortedConfigs.insert(0, hollandConfig);
    }

    // 4. Attempt each config in order
    for (int i = 0; i < sortedConfigs.length; i++) {
      if (cancelRequested) {
        return false;
      }
      final config = sortedConfigs[i];

      await VpnConnection.connect(config);

      await Future.delayed(const Duration(milliseconds: 1000));

      while (true) {
        if (VpnConnection.status.value.state == 'CONNECTED') break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      ping = await checkInternetWithPing();
      if (ping != null) {
        await saveLastWorkingConfig(config); // ✅ Save working config
        // setState(() {
        //   selectedConfig = config;
        //   isConnected = true;
        // });
        // if (cameFromSaved) {
        //   // vpnConfigs.clear();
        //   await initializeVpnConfigs();
        //   cameFromSaved = false;
        // }
        //fetchCurrentIpInfo();
        return true;
      }

      // ❌ If connection fails, stop and try next
      await VpnConnection.disconnect();
      await Future.delayed(const Duration(milliseconds: 1000));
      while (true) {
        if (VpnConnection.status.value.state == 'DISCONNECTED') break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return false; // ❌ No config worked
  }

  // int ipFetchRetryCount = 0;

  // void fetchCurrentIpInfo() async {
  //   if (isFetchingIp) return;

  //   setState(() {
  //     isFetchingIp = true;
  //   });

  //   final dio = Dio(
  //     BaseOptions(
  //       connectTimeout: const Duration(seconds: 2),
  //       receiveTimeout: const Duration(seconds: 2),
  //     ),
  //   );

  //   final url = 'https://ipwho.is/';
  //   int attempt = 0;
  //   String? resolvedCountry;

  //   while (true) {
  //     try {
  //       final response = await dio.get(url);

  //       if (response.statusCode == 200 && response.data != null) {
  //         final data = response.data;
  //         final code = isConnected ? data['country'] : data['country_code'];
  //         final name = countryCodeToPersian[code] ?? code;

  //         resolvedCountry = name == 'پرو' ? 'آمریکا' : name;
  //         break;
  //       } else {
  //         debugPrint("❌ API Error: ${response.statusCode}");
  //       }
  //     } on DioException catch (e) {
  //       debugPrint("❌ Dio error on attempt ${attempt + 1}: ${e.message}");
  //     } catch (e) {
  //       debugPrint("❌ General error on attempt ${attempt + 1}: $e");
  //     }

  //     attempt++;

  //     if (!isConnected && attempt >= 2) {
  //       resolvedCountry = "ایران";
  //       debugPrint("⚠️ IP fetch failed after 2 attempts. Defaulted to ایران.");
  //       break;
  //     }

  //     await Future.delayed(const Duration(milliseconds: 1500));
  //   }

  //   setState(() {
  //     country = resolvedCountry;
  //     isFetchingIp = false;
  //   });
  // }

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
                    onTap: () async {
                      setState(() {
                        selectedDropdownOption = 'auto';
                        selectedConfig = null;
                        selectedServerPing = null;
                      });
                      // Save to SharedPreferences
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'selectedDropdownOption',
                        'auto',
                      ); // or config.id if it's a full object

                      toggleDropdown();
                    },
                    title: const Center(
                      child: Text(
                        'Auto Server Selection',
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
                        onTap: () async {
                          setState(() {
                            selectedDropdownOption = config;
                            selectedConfig = config;
                            selectedServerPing = null;
                          });
                          // Save to SharedPreferences
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(
                            'selectedDropdownOption',
                            config,
                          ); // or config.id if it's a full object

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
  int calculatePingStrength(int ping) {
    debugPrint('$ping');
    if (ping < 700) return 5; // excellent
    if (ping < 1400) return 4; // good
    if (ping < 2100) return 3; // okay
    if (ping < 2800) return 2; // bad
    return 1; // terrible
  }

  Color getPingColor(int ping) {
    if (ping < 700) return Colors.green;
    if (ping < 1400) return Colors.lightGreen;
    if (ping < 2100) return Colors.orange;
    if (ping < 2800) return Colors.deepOrange;
    return Colors.red;
  }

  void startConnectionMonitor() {
    if (_monitoringConnection) return;
    _monitoringConnection = true;

    () async {
      while (isConnected && _monitoringConnection) {
        final newPing = await checkInternetWithPing(pingOnly: true);
        final success = newPing != null;

        ping = newPing;

        if (!success && isAppActive && isConnected) {
          failedChecks++;
        } else {
          failedChecks = 0;
          setState(() => seemsDisconnected = false);
        }

        if (failedChecks >= maxFailures) {
          seemsDisconnected = true;
        }

        // stop monitoring if V2Ray reports disconnected
        if (VpnConnection.status.value.state == 'DISCONNECTED') {
          _monitoringConnection = false;
          await VpnConnection.disconnect();
          setState(() {
            isConnected = false;
            isCheckingConnection = false;
          });
          //fetchCurrentIpInfo();
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
    setState(() => isFetchingVpnConfig = true);

    try {
      setState(() {
        loadingMessage = 'اتصال سریع';
      });

      VpnAccount? result = await VpnService.getVpnAccount(
        progressNotifier,
        () async {},
        onlyCheckFirstDomain: true,
      );

      if (result != null) {
        debugPrint("✅ First domain succeeded — skipping rest of flow");
        await _finalizeVpnAccount(result);
        setState(() {
          cameFromSaved = false; // ✅ mark as fresh fetch
        });
        return;
      }

      setState(() {
        loadingMessage = 'بررسی اتصال اینترنت';
      });

      final pingTimeIran = await checkInternetWithPing(useIranianSite: true);
      if (pingTimeIran == null) {
        setState(() {
          loadingMessage = 'اینترنت متصل نیست';
          isFetchingVpnConfig = false;
        });

        if (hasCachedAccount) {
          showMyToast(
            "اتصال اینترنت برقرار نیست",
            context,
            backgroundColor: Colors.red,
          );
        }
        return;
      }

      final pingTimeInternational = await checkInternetWithPing(
        useIranianSite: false,
      );
      if (pingTimeInternational == null) {
        setState(() {
          loadingMessage = 'اینترنت شما ملی است';
          isFetchingVpnConfig = false;
        });

        if (hasCachedAccount) {
          showMyToast("اینترنت ملی است", context, backgroundColor: Colors.red);
        }
        return;
      }

      setState(() {
        loadingMessage = 'ارتباط با سرور';
      });

      result = await VpnService.getVpnAccount(progressNotifier, () async {});

      if (result == null) throw Exception('دریافت اطلاعات حساب ناموفق بود');

      await _finalizeVpnAccount(result);
      setState(() {
        cameFromSaved = false; // ✅ mark as fresh fetch
      });
    } catch (e) {
      debugPrint("❌ Subscription fetch failed: $e");

      if (hasCachedAccount) {
        showMyToast(
          "خطا در دریافت اطلاعات",
          context,
          backgroundColor: Colors.red,
        );
      }
    } finally {
      setState(() => isFetchingVpnConfig = false);
    }
  }

  String convertToPersianNumber(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], persian[i]);
    }
    return input;
  }

  Future<void> resetVpnWithRealConfig(String config, String remark) async {
    debugPrint("Inside -----");
    await Future.delayed(const Duration(milliseconds: 1000));
    if (VpnConnection.status.value.state == 'CONNECTED') {
      debugPrint("Connected -----");

      // VPN is already active — just monitor it
      final savedConfig = await getLastWorkingConfig();
      selectedConfig = savedConfig;
      setState(() {
        isConnected = true;
      });
      startConnectionMonitor();
      //fetchCurrentIpInfo(); // ✅ Begin monitoring
      return;
    }
    debugPrint("Not Connected -----");

    // try {
    //   await VpnConnection.connect(
    //     config,
    //     proxyOnly: false,
    //     blockedApps: null,
    //     bypassSubnets: null,
    //   );
    //   debugPrint("Connecting -----");

    //   // ✅ Wait until it's connected
    //   while (VpnConnection.status.value.state != 'CONNECTED') {
    //     await Future.delayed(const Duration(milliseconds: 100));
    //   }
    //   debugPrint("Successful -----");

    //   // ✅ Immediately stop to flush out other VPN apps
    //   await VpnConnection.disconnect();
    //   debugPrint("Disconnecting Successful -----");

    //   //fetchCurrentIpInfo(); // 🧠 Refresh IP info, DNS, etc.
    // } catch (e) {
    //   // Optionally log
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedPageIndex == 0 ? _buildConnectPage() : _buildAccountPage(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isConnected
              ? Colors.green
              : subscriptionStatus == 'expired' ||
                    subscriptionStatus == 'unknown'
              ? Colors.red
              : const Color(0xFF9700FF),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Connect button
                IconButton(
                  icon: Icon(Icons.vpn_key, color: Colors.white, size: 28),
                  onPressed: () {
                    setState(() {
                      _selectedPageIndex = 0;
                    });
                  },
                ),
                // Account button
                IconButton(
                  icon: Icon(
                    Icons.account_circle,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedPageIndex = 1;
                    });
                  },
                ),
                // Refresh button
                IconButton(
                  icon: isFetchingVpnConfig
                      ? LoadingAnimationWidget.threeArchedCircle(
                          color: Colors.white,
                          size: 28,
                        )
                      : Icon(Icons.cloud_done, color: Colors.white, size: 28),
                  onPressed: isFetchingVpnConfig
                      ? null
                      : () async {
                          await initializeVpnConfigs();
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectPage() {
    return Stack(
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
                            height: 195,
                            color: isConnected
                                ? Colors.green
                                : subscriptionStatus == 'expired' ||
                                      subscriptionStatus == 'unknown'
                                ? Colors.red
                                : const Color(
                                    0xFF9700FF,
                                  ), // blue when not connected and not expired
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
                            ),
                            // spacing from top
                            const Text(
                              'Global',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w500, // or w600 or normal
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ), // spacing from top
                            // other body content goes here...
                          ],
                        ),
                      ],
                    ),
                    // Center the content vertically with adjustment for navbar
                    Expanded(
                      child: Align(
                        alignment: Alignment(0, -0.5), // Shifted up from center
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Server Dropdown
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 15,
                                            ),
                                            child: isOpen
                                                ? const Text(
                                                    'Select a server to connect',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  )
                                                : isCheckingConnection
                                                ? cancelRequested
                                                      ? const Text(
                                                          'Canceling connection',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        )
                                                      : Row(
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
                                                        ),
                                                    child: Center(
                                                      child: !seemsDisconnected
                                                          ? (ping != null
                                                                ? StepProgressIndicator(
                                                                    totalSteps:
                                                                        5,
                                                                    currentStep:
                                                                        calculatePingStrength(
                                                                          ping!,
                                                                        ),
                                                                    size: 31,
                                                                    padding: 2,
                                                                    selectedColor:
                                                                        getPingColor(
                                                                          ping!,
                                                                        ),
                                                                    unselectedColor:
                                                                        Colors
                                                                            .grey
                                                                            .shade800,
                                                                    roundedEdges:
                                                                        const Radius.circular(
                                                                          7,
                                                                        ),
                                                                  )
                                                                : const Text(
                                                                    'Checking connection quality',
                                                                    style: TextStyle(
                                                                      color: Colors
                                                                          .green,
                                                                      fontSize:
                                                                          18,
                                                                    ),
                                                                  ))
                                                          : const Text(
                                                              'Not connected',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                                fontSize: 18,
                                                              ),
                                                            ),
                                                    ),
                                                  )
                                                : Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 30,
                                                        ),
                                                    child:
                                                        selectedDropdownOption ==
                                                            'auto'
                                                        ? const Text(
                                                            'Auto Server Selection',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 18,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          )
                                                        : Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            textDirection:
                                                                TextDirection
                                                                    .ltr,
                                                            children: [
                                                              // 🏳️ Flag
                                                              buildFlag(
                                                                getCountryCodeFromLink(
                                                                  selectedConfig ??
                                                                      '',
                                                                ),
                                                                link:
                                                                    selectedConfig ??
                                                                    '',
                                                              ),

                                                              // 📦 Server Label
                                                              Flexible(
                                                                child: Text(
                                                                  getServerLabel(
                                                                    selectedConfig ??
                                                                        '',
                                                                  ),
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        18,
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
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Connect/Disconnect Button (Large Square)
                              GestureDetector(
                                onTap: () async {
                                  currentTestingIndex = 0;
                                  // final serverLabel = getServerLabel(
                                  //   selectedConfig ?? '',
                                  // );
                                  // final isIranServer = serverLabel.contains(
                                  //   "ایران",
                                  // );

                                  // if ((subscriptionStatus == 'expired' ||
                                  //         subscriptionStatus == 'unknown') &&
                                  //     !isIranServer) {
                                  if (subscriptionStatus == 'unknown') {
                                    showMyToast(
                                      "Your subscription data has run out",
                                      context,
                                      backgroundColor: Colors.red,
                                    );
                                    return;
                                  }

                                  if (subscriptionStatus == 'expired') {
                                    showMyToast(
                                      "Your subscription time has expired",
                                      context,
                                      backgroundColor: Colors.red,
                                    );
                                    return;
                                  }

                                  // 🔁 Allow canceling the connection while it's in progress
                                  if (isCheckingConnection) {
                                    setState(() {
                                      cancelRequested = true;
                                    });
                                    debugPrint('🛑 Cancel requested');
                                    return;
                                  }
                                  if (vpnConfigs.isEmpty) {
                                    return;
                                  }
                                  if (!isConnected) {
                                    setState(() {
                                      isCheckingConnection = true;
                                      cancelRequested = false;
                                    });

                                    bool success = false;
                                    final currentContext = context;

                                    if (selectedDropdownOption == "auto") {
                                      success = await autoConnect();
                                    } else {
                                      try {
                                        if (cancelRequested) {
                                          setState(
                                            () => isCheckingConnection = false,
                                          );
                                          return;
                                        }

                                        await VpnConnection.connect(
                                          selectedConfig!,
                                        );
                                      } catch (e) {
                                        debugPrint("❌ VPN connect failed: $e");
                                        setState(
                                          () => isCheckingConnection = false,
                                        );
                                        return;
                                      }

                                      // Wait for connection or cancellation
                                      while (true) {
                                        if (cancelRequested) {
                                          debugPrint(
                                            "🛑 Cancelled by user before connect",
                                          );
                                          await VpnConnection.disconnect();
                                          setState(
                                            () => isCheckingConnection = false,
                                          );
                                          return;
                                        }

                                        final status =
                                            VpnConnection.status.value;
                                        if (status.state == 'CONNECTED') {
                                          break;
                                        }
                                        await Future.delayed(
                                          const Duration(milliseconds: 100),
                                        );
                                      }

                                      if (!cancelRequested) {
                                        ping = await checkInternetWithPing();
                                        success = ping != null;
                                      }
                                    }

                                    if (success && !cancelRequested) {
                                      setState(() {
                                        isConnected = true;
                                        isCheckingConnection = false;
                                      });
                                      startConnectionMonitor();
                                      if (cameFromSaved) {
                                        // vpnConfigs.clear();
                                        await initializeVpnConfigs();
                                        cameFromSaved = false;
                                      }
                                      //fetchCurrentIpInfo();

                                      if (selectedConfig != null) {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setString(
                                          'last_working_config',
                                          selectedConfig!,
                                        );
                                      }
                                    } else {
                                      await VpnConnection.disconnect();
                                      setState(() {
                                        isConnected = false;
                                        isCheckingConnection = false;
                                      });
                                      //fetchCurrentIpInfo();

                                      if (!cancelRequested) {
                                        showMyToast(
                                          selectedDropdownOption == "auto"
                                              ? "No server connected. Please refresh servers or contact support."
                                              : "Connection failed. Please select another server.",
                                          currentContext,
                                          backgroundColor: Colors.red,
                                        );
                                      }
                                    }
                                  } else {
                                    await VpnConnection.disconnect();
                                    stopConnectionMonitor();

                                    setState(() {
                                      isConnected = false;
                                    });
                                    //fetchCurrentIpInfo();
                                  }
                                },
                                child: Container(
                                  width: 310,
                                  height: 310,
                                  decoration: BoxDecoration(
                                    color: isConnected
                                        ? Colors.green
                                        : subscriptionStatus == 'expired' ||
                                              subscriptionStatus == 'unknown'
                                        ? Colors.red
                                        : const Color(
                                            0xFF9700FF,
                                          ), // blue when not connected and not expired

                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Center(
                                    child:
                                        isCheckingConnection ||
                                            vpnConfigs.isEmpty
                                        ? LoadingAnimationWidget.threeArchedCircle(
                                            color: Colors.white,
                                            size: 50,
                                          )
                                        : Text(
                                            isConnected
                                                ? 'Disconnect'
                                                : 'Connect',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Update Banner
                              FutureBuilder<String>(
                                future: _getAppVersion(),
                                builder: (context, snapshot) {
                                  final localVersion = snapshot.data ?? '';
                                  return UpdateBanner(
                                    currentVersion: localVersion,
                                    latestVersion: account?.latestVersion,
                                    updateUrl: account?.updateUrl,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (vpnConfigs.isEmpty && !hasCachedAccount)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
              child: Container(
                color: const Color(0xFF303030).withAlpha(50),
                child: Stack(
                  children: [
                    // Centered ZURTEX content
                    Center(
                      child: LoadingProgressWidget(
                        loadingMessage: loadingMessage,
                        progressNotifier: progressNotifier,
                      ),
                    ),
                    // Bottom actions
                    if (loadingMessage == 'خطا در دریافت اطلاعات' ||
                        loadingMessage == 'اینترنت متصل نیست' ||
                        loadingMessage == 'اینترنت شما ملی است')
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Text Buttons Row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 80,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      launchUrl(
                                        Uri.parse('https://t.me/AppSupport96'),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                    child: const Text(
                                      'پشتیبانی',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                        decoration: TextDecoration.none,
                                      ),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      //vpnConfigs.clear();
                                      await initializeVpnConfigs();
                                    },
                                    child: const Text(
                                      'تلاش مجدد',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                        decoration: TextDecoration.none,
                                      ),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      launchUrl(
                                        Uri.parse(
                                          'https://t.me/ZurtexV2rayApp',
                                        ),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                    child: const Text(
                                      'کانال تلگرام',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                        decoration: TextDecoration.none,
                                      ),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 15),

                            // Version + Username
                            GestureDetector(
                              onTap: () {
                                final usernametoCopy =
                                    account?.username ?? username;
                                if (usernametoCopy != null) {
                                  Clipboard.setData(
                                    ClipboardData(text: usernametoCopy),
                                  );
                                }
                              },
                              onLongPress: () async {
                                // Copy email instead of device ID
                                final email = await AuthService.getUserEmail();
                                if (email != null) {
                                  Clipboard.setData(ClipboardData(text: email));
                                }
                              },
                              child: FutureBuilder<String>(
                                future: _getAppVersion(),
                                builder: (context, snapshot) {
                                  final version = snapshot.data ?? '';
                                  final user =
                                      account?.username ?? username ?? '---';
                                  return Text(
                                    'V$version  $user',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      decoration: TextDecoration.none,
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
    );
  }

  Widget _buildAccountPage() {
    return Container(
      color: const Color(0xFF212121),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Account Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Email
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF303030),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            username ?? 'Loading...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Days Left
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF303030),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Days Remaining',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            account?.remainingDays.toString() ?? '---',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Data Left
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF303030),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data Remaining',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${account?.remainingGB.toStringAsFixed(1) ?? '--'} GB',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Subscription Status
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF303030),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subscriptionStatus == 'active'
                                ? 'Active'
                                : subscriptionStatus == 'expired'
                                ? 'Expired'
                                : 'Unknown',
                            style: TextStyle(
                              color: subscriptionStatus == 'active'
                                  ? Colors.green
                                  : subscriptionStatus == 'expired'
                                  ? Colors.red
                                  : Colors.orange,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Placeholder for renewal button (to be added later)
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
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
