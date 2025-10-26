// ignore_for_file: use_build_context_synchronously
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zurtex/services/vpn_connection.dart';
import 'package:zurtex/services/vpn_service.dart';
import 'package:zurtex/services/auth_service.dart';
import 'package:zurtex/services/payment_service.dart';
import 'package:zurtex/models/payment_order.dart';
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

// Map to get English country name from flag emoji
const Map<String, String> flagToCountryName = {
  '🇩🇪': 'Germany',
  '🇺🇸': 'United States',
  '🇫🇷': 'France',
  '🇮🇷': 'Iran',
  '🇨🇦': 'Canada',
  '🇬🇧': 'United Kingdom',
  '🇹🇷': 'Turkey',
  '🇦🇪': 'UAE',
  '🇯🇵': 'Japan',
  '🇳🇱': 'Netherlands',
  '🇮🇹': 'Italy',
  '🇫🇮': 'Finland',
  '🇵🇪': 'Peru',
  '🇷🇺': 'Russia',
  '🇨🇳': 'China',
  '🇮🇳': 'India',
  '🇧🇷': 'Brazil',
  '🇪🇸': 'Spain',
  '🇸🇪': 'Sweden',
  '🇨🇭': 'Switzerland',
  '🇦🇺': 'Australia',
  '🇦🇹': 'Austria',
  '🇸🇬': 'Singapore',
  '🇰🇷': 'South Korea',
  '🇰🇿': 'Kazakhstan',
  '🇺🇦': 'Ukraine',
  '🇵🇱': 'Poland',
  '🇦🇷': 'Argentina',
  '🇲🇽': 'Mexico',
  '🇸🇦': 'Saudi Arabia',
  '🇮🇶': 'Iraq',
  '🇸🇾': 'Syria',
  '🇶🇦': 'Qatar',
};

/// Extract clean notification remark (flag + English country name only)
String getCleanNotificationRemark(String configUrl) {
  // Get the remark from URL fragment
  final fragment = configUrl.split('#').length > 1
      ? configUrl.split('#')[1]
      : '';
  final remark = Uri.decodeComponent(fragment);

  // Find flag emoji in remark by checking each character
  String? foundFlag;
  for (final entry in flagToCountryName.entries) {
    if (remark.contains(entry.key)) {
      foundFlag = entry.key;
      break;
    }
  }

  if (foundFlag != null) {
    final countryName = flagToCountryName[foundFlag] ?? 'VPN';
    return '$foundFlag $countryName';
  }

  // Fallback if no flag found
  return 'Zurtex VPN';
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
  String loadingMessage = 'Loading account information';
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
  String? email;
  final ValueNotifier<double> progressNotifier = ValueNotifier(360);
  late final String rawLabel;
  late final String staticIranConfig;
  bool cancelRequested = false;
  bool hasCachedAccount = true;
  // late AnimationController _arrowPulseController;
  bool cameFromSaved = false;
  bool isFetchingVpnConfig = false;
  int _selectedPageIndex = 0; // Navigation bar state

  // Payment-related state
  bool _isPaymentExpanded = false;
  PaymentOrder? _currentPaymentOrder;
  List<PaymentPlan> _paymentPlans = [];
  bool _isLoadingPlans = false;
  bool _isCreatingPayment = false;
  String? _planLoadError; // Error message when loading plans fails
  Timer? _paymentStatusTimer;
  String? _selectedPlanType; // Track selected plan
  bool _isRefreshingPayment = false; // Cooldown state for refresh button

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
    AuthService.getUserEmail().then((value) {
      setState(() {
        email = value;
      });
    });
    fToast = FToast();
    fToast.init(context);
    initializeVpnConfigs();
    _loadPaymentData();
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

      await VpnConnection.connect(
        config,
        customRemark: getCleanNotificationRemark(config),
      );

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
        loadingMessage = 'Quick connect';
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
        loadingMessage = 'Checking internet connection';
      });

      final pingTimeIran = await checkInternetWithPing(useIranianSite: true);
      if (pingTimeIran == null) {
        setState(() {
          loadingMessage = 'No internet connection';
          isFetchingVpnConfig = false;
        });

        if (hasCachedAccount) {
          showMyToast(
            "No internet connection",
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
          loadingMessage = 'National internet only';
          isFetchingVpnConfig = false;
        });

        if (hasCachedAccount) {
          showMyToast(
            "National internet only",
            context,
            backgroundColor: Colors.red,
          );
        }
        return;
      }

      setState(() {
        loadingMessage = 'Connecting to server';
      });

      result = await VpnService.getVpnAccount(progressNotifier, () async {});

      if (result == null) {
        throw Exception('Failed to fetch account information');
      }

      await _finalizeVpnAccount(result);
      setState(() {
        cameFromSaved = false; // ✅ mark as fresh fetch
      });
    } catch (e) {
      debugPrint("❌ Subscription fetch failed: $e");

      if (hasCachedAccount) {
        showMyToast(
          "Error fetching data",
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
                                          customRemark:
                                              getCleanNotificationRemark(
                                                selectedConfig!,
                                              ),
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
                    if (loadingMessage == 'Error fetching data' ||
                        loadingMessage == 'No internet connection' ||
                        loadingMessage == 'National internet only')
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
            // Account Info - Make scrollable
            Expanded(
              child: SingleChildScrollView(
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
                            email ?? 'Loading...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Days Remaining and Status in one row
                    Row(
                      children: [
                        // Days Remaining
                        Expanded(
                          child: Container(
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
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
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
                        ),
                        const SizedBox(width: 16),
                        // Subscription Status
                        Expanded(
                          child: Container(
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
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Payment Section
                    _buildPaymentSection(),
                    const SizedBox(height: 16),
                    // Contact Support Button
                    _buildContactSupportButton(),
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

  Widget _buildContactSupportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            final url = Uri.parse('https://t.me/MyAppsSupport96');
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('Error opening Telegram: $e');
            showMyToast(
              'Could not open Telegram. Please install Telegram app.',
              context,
              backgroundColor: Colors.red,
            );
          }
        },
        icon: Image.asset('assets/images/Telegram.png', width: 24, height: 24),
        label: const Text(
          'Contact Support',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0088cc),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ==================== PAYMENT METHODS ====================

  Future<void> _loadPaymentData() async {
    // Load saved payment order
    final order = await PaymentService.getCurrentPaymentOrder();
    if (order != null && mounted) {
      setState(() {
        _currentPaymentOrder = order;
      });

      // If payment is pending or confirming, start monitoring
      if (order.isPending || order.isConfirming) {
        _startPaymentMonitoring();
      }

      // If payment is completed, clear it after showing success
      if (order.isCompleted) {
        await Future.delayed(const Duration(seconds: 2));
        await PaymentService.clearCompletedPayment();
        if (mounted) {
          setState(() {
            _currentPaymentOrder = null;
          });
        }
      }
    }

    // Don't load payment plans on init - load them when user expands the section
  }

  Future<void> _loadPaymentPlans() async {
    if (!mounted) return;

    setState(() {
      _isLoadingPlans = true;
      _planLoadError = null;
    });

    try {
      final plans = await PaymentService.getPlans();
      // Filter to only show 30 days and 730 days (2 years)
      final filteredPlans = plans
          .where((plan) => plan.type == '30_days' || plan.type == '730_days')
          .toList();

      if (mounted) {
        setState(() {
          _paymentPlans = filteredPlans;
          _isLoadingPlans = false;
          _planLoadError = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading payment plans: $e');
      if (mounted) {
        setState(() {
          _isLoadingPlans = false;
          _planLoadError = 'Connection failed';
        });
      }
    }
  }

  Future<void> _createPayment(String planType) async {
    if (!mounted) return;

    setState(() {
      _isCreatingPayment = true;
    });

    try {
      final order = await PaymentService.createPayment(planType);
      if (mounted) {
        setState(() {
          _currentPaymentOrder = order;
          _isCreatingPayment = false;
        });

        // Start monitoring payment status
        _startPaymentMonitoring();

        showMyToast(
          'Payment order created',
          context,
          backgroundColor: Colors.green,
        );
      }
    } catch (e) {
      debugPrint('Error creating payment: $e');
      if (mounted) {
        setState(() {
          _isCreatingPayment = false;
        });
        showMyToast(
          'Failed to create payment',
          context,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _startPaymentMonitoring() {
    _paymentStatusTimer?.cancel();
    _paymentStatusTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final order = _currentPaymentOrder;
      if (order == null) {
        timer.cancel();
        return;
      }

      try {
        final updatedOrder = await PaymentService.checkPaymentStatus(
          order.orderId,
        );

        if (mounted) {
          setState(() {
            _currentPaymentOrder = updatedOrder;
          });
        }

        // If completed, stop monitoring and refresh account
        if (updatedOrder.isCompleted) {
          timer.cancel();
          if (mounted) {
            showMyToast(
              'Payment completed! Your subscription has been activated.',
              context,
              backgroundColor: Colors.green,
            );
          }
          // Refresh account data
          await initializeVpnConfigs();

          // Clear payment after a delay
          await Future.delayed(const Duration(seconds: 3));
          await PaymentService.clearCompletedPayment();
          if (mounted) {
            setState(() {
              _currentPaymentOrder = null;
            });
          }
        }

        // If expired, stop monitoring
        if (updatedOrder.isExpired && updatedOrder.isPending) {
          timer.cancel();
          if (mounted) {
            showMyToast(
              'Payment expired',
              context,
              backgroundColor: Colors.orange,
            );
          }
        }
      } catch (e) {
        debugPrint('Error checking payment status: $e');
      }
    });
  }

  Future<void> _cancelPayment() async {
    await PaymentService.cancelPayment();
    _paymentStatusTimer?.cancel();
    if (mounted) {
      setState(() {
        _currentPaymentOrder = null;
      });
      showMyToast('Payment cancelled', context, backgroundColor: Colors.grey);
    }
  }

  Widget _buildPaymentSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF303030),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header with expand/collapse button
          InkWell(
            onTap: () {
              setState(() {
                _isPaymentExpanded = !_isPaymentExpanded;
              });
              // Load plans when expanding
              if (_isPaymentExpanded &&
                  _paymentPlans.isEmpty &&
                  !_isLoadingPlans) {
                _loadPaymentPlans();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Renew Subscription',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _isPaymentExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_isPaymentExpanded) ...[
            const Divider(color: Colors.grey, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _currentPaymentOrder == null
                  ? _buildPlanSelection()
                  : _buildPaymentInfo(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanSelection() {
    final themeColor = isConnected
        ? Colors.green
        : subscriptionStatus == 'expired' || subscriptionStatus == 'unknown'
        ? Colors.red
        : const Color(0xFF9700FF);

    if (_isLoadingPlans) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: themeColor),
        ),
      );
    }

    // Show error with retry button
    if (_planLoadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _planLoadError!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPaymentPlans,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_paymentPlans.isEmpty) {
      return const Text(
        'No payment plans available',
        style: TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      );
    }

    return Column(
      children: [
        // Plan options
        ..._paymentPlans.map((plan) => _buildPlanOption(plan)),
        const SizedBox(height: 16),
        // Confirm button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isCreatingPayment || _selectedPlanType == null
                ? null
                : () {
                    _createPayment(_selectedPlanType!);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isCreatingPayment
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _selectedPlanType == null ? 'Select a Plan' : 'Confirm',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanOption(PaymentPlan plan) {
    final discount = plan.getDiscountPercentage();
    final originalPrice = plan.getOriginalPrice();
    final monthlyPrice = plan.getMonthlyPrice();
    final isSelected = _selectedPlanType == plan.type;
    final themeColor = isConnected
        ? Colors.green
        : subscriptionStatus == 'expired' || subscriptionStatus == 'unknown'
        ? Colors.red
        : const Color(0xFF9700FF);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanType = plan.type;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : const Color(0xFF404040),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: themeColor, width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.getDisplayName(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                if (discount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-${discount.toInt()}%',
                      style: TextStyle(
                        color: isSelected ? themeColor : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (plan.days > 30)
              Text(
                '\$${monthlyPrice.toStringAsFixed(2)} per month',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white.withValues(alpha: .9)
                      : Colors.grey,
                  fontSize: 14,
                ),
              ),
            if (plan.days > 30) const SizedBox(height: 8),
            Row(
              children: [
                if (originalPrice != null) ...[
                  Text(
                    '\$${originalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '\$${plan.priceUSD.toStringAsFixed(2)} total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfo() {
    final order = _currentPaymentOrder!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order info
        Text(
          'Order ID: ${order.orderId.substring(0, 8)}...',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),

        // Plan name
        Text(
          order.getPlanDisplayName(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Amount
        Text(
          '${order.amount.toStringAsFixed(8)} LTC (\$${order.amountUSD.toStringAsFixed(2)})',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 16),

        // Payment address
        const Text(
          'Send Litecoin to:',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: order.paymentAddress));
            showMyToast(
              'Address copied',
              context,
              backgroundColor: Colors.green,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF404040),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    order.paymentAddress,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.copy, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // QR Code
        if (order.qrCode.isNotEmpty) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.memory(
                base64Decode(order.qrCode.split(',').last),
                key: ValueKey(order.orderId),
                width: 200,
                height: 200,
                gaplessPlayback: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Status
        Text(
          order.getStatusMessage(),
          style: TextStyle(
            color: order.isCompleted
                ? Colors.green
                : order.isConfirming
                ? Colors.orange
                : order.isUnderpaid
                ? Colors.red
                : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (order.confirmations > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Confirmations: ${order.confirmations}/2',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
        if (order.isUnderpaid && order.amountReceived > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Received: ${order.amountReceived.toStringAsFixed(8)} LTC',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Please contact support for manual processing',
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
        if (!order.isExpired && order.isPending) ...[
          const SizedBox(height: 4),
          Text(
            'Expires: ${_formatDateTime(order.expiresAt)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),

        // Refresh button
        if (!order.isCompleted) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRefreshingPayment
                  ? null
                  : () async {
                      setState(() {
                        _isRefreshingPayment = true;
                      });

                      try {
                        final updatedOrder =
                            await PaymentService.refreshPaymentStatus(
                              order.orderId,
                            );
                        if (mounted) {
                          setState(() {
                            _currentPaymentOrder = updatedOrder;
                          });
                          showMyToast(
                            'Payment status updated',
                            context,
                            backgroundColor: Colors.green,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          showMyToast(
                            'Failed to refresh status',
                            context,
                            backgroundColor: Colors.red,
                          );
                        }
                      }

                      // Start 5-second cooldown
                      Future.delayed(const Duration(seconds: 5), () {
                        if (mounted) {
                          setState(() {
                            _isRefreshingPayment = false;
                          });
                        }
                      });
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Check Payment Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRefreshingPayment
                    ? const Color(0xFFBDBDBD) // Light grey (grey[400])
                    : (isConnected
                          ? Colors.green
                          : subscriptionStatus == 'expired' ||
                                subscriptionStatus == 'unknown'
                          ? Colors.red
                          : const Color(0xFF9700FF)),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Cancel button
        if (!order.isCompleted && !order.isUnderpaid)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF303030),
                    title: const Text(
                      'Cancel Payment?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Are you sure you want to cancel this payment order?',
                      style: TextStyle(color: Colors.grey),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Yes, Cancel',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _cancelPayment();
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancel Payment',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.isNegative) return 'Expired';

    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      return '${diff.inMinutes}m';
    }
  }

  // ==================== END PAYMENT METHODS ====================

  @override
  void dispose() {
    _paymentStatusTimer?.cancel();
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
