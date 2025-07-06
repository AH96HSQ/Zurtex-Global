// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zurtex/models/vpn_account.dart';
import 'package:zurtex/screens/home_screen.dart';
import 'package:zurtex/utils/toast_utils.dart';
import 'package:zurtex/widgets/package_selector.dart';
// import 'package:zurtex/utils/toast_utils.dart'; // adjust if your package name differs

class RenewalSheet extends StatefulWidget {
  final VpnAccount account;
  final Function(VpnAccount) onReceiptSubmitted;

  const RenewalSheet({
    required this.account,
    required this.onReceiptSubmitted,
    super.key,
  });

  @override
  State<RenewalSheet> createState() => _RenewalSheetState(); // ✅ Add this
}

class _RenewalSheetState extends State<RenewalSheet> {
  String selectedTier = '1 ماهه';
  File? receiptFile;
  String? deviceId;
  bool isRenewalLoading = true;
  Map<String, dynamic>? renewalData;
  String? serverMessage;
  bool messageDismissed = false;
  int selectedDays = 30;
  int selectedGB = 30;
  bool isUploading = false;
  int serverProvidedDayPrice = 750;
  int serverProvidedGbPrice = 3500;
  String? remainingGB;
  int? remainingDays;
  bool isImageUnsupported = false;

  @override
  void initState() {
    super.initState();
    fetchDeviceId();
    remainingGB = (widget.account.gigBytes / (1024 * 1024 * 1024))
        .toStringAsFixed(0);
    remainingDays = DateTime.fromMillisecondsSinceEpoch(
      widget.account.expiryTime * 1000,
    ).difference(DateTime.now()).inDays;
  }

  String formatWithSpaces(int number) {
    final str = number.toString();
    final buffer = StringBuffer();

    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }

    return buffer.toString().split('').reversed.join();
  }

  Future<void> fetchRenewalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDomain = prefs.getString('last_working_domain');

      if (lastDomain == null) {
        debugPrint("❌ No last working domain saved");
        showMyToast(
          "دامنه معتبر یافت نشد",
          context,
          backgroundColor: Colors.red,
        );
        setState(() => isRenewalLoading = false);
        return;
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final res = await dio.get(
        'http://$lastDomain/api/renewal',
        queryParameters: {'deviceId': deviceId},
      );

      if (res.statusCode == 200) {
        final data = res.data;

        setState(() {
          renewalData = data;
          serverMessage = data['message'];
          serverProvidedDayPrice = data['pricePerDay'] ?? 400;
          serverProvidedGbPrice = data['pricePerGB'] ?? 3000;
          messageDismissed = false;
          isRenewalLoading = false;
        });
      } else {
        debugPrint("❌ Server responded with ${res.statusCode}");
        setState(() => isRenewalLoading = false);
        showMyToast(
          "در حال حاضر تمدید مسدود است",
          context,
          backgroundColor: Colors.red,
        );
      }
    } on DioException catch (e) {
      debugPrint("❌ Dio error: ${e.message}");
      showMyToast(
        "مشکل در ارتباط با سرور",
        context,
        backgroundColor: Colors.red,
      );
      setState(() => isRenewalLoading = false);
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint("❌ Unknown error: $e");
      showMyToast(
        "خطای نامشخص هنگام تمدید",
        context,
        backgroundColor: Colors.red,
      );
      setState(() => isRenewalLoading = false);
      Navigator.of(context).pop();
    }
  }

  Future<void> submitReceipt(
    BuildContext context,
    String base64Receipt,
    String lastDomain,
  ) async {
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
          'User-Agent': 'ZurtexClient/1.0',
        },
      ),
    );

    final uri = 'http://$lastDomain/api/receipt';

    try {
      final int totalPrice =
          (selectedDays * serverProvidedDayPrice) +
          (selectedGB * serverProvidedGbPrice);

      final response = await dio.post(
        uri,
        data: {
          "deviceId": deviceId,
          "receiptData": base64Receipt,
          "gigabyte": selectedGB,
          "durationInDays": selectedDays,
          "price": totalPrice,
        },
      );

      if (response.statusCode == 200) {
        showMyToast(
          "رسید با موفقیت ارسال شد",
          context,
          backgroundColor: Colors.green,
        );

        widget.onReceiptSubmitted(
          VpnAccount(
            username: widget.account.username,
            test: widget.account.test,
            expiryTime: widget.account.expiryTime,
            gigBytes: widget.account.gigBytes,
            status: widget.account.status,
            takLinks: widget.account.takLinks,
            hasPendingReceipt: true,
            messages: widget.account.messages,
          ),
        );

        Navigator.of(context).pop();
      } else {
        debugPrint("❌ Server responded with: ${response.statusCode}");
        showMyToast("خطا در ارسال رسید", context, backgroundColor: Colors.red);
      }
    } on DioException catch (e) {
      debugPrint("❌ Dio error during receipt upload: ${e.message}");
      showMyToast(
        "ارسال رسید با خطا مواجه شد",
        context,
        backgroundColor: Colors.red,
      );
    } catch (e) {
      debugPrint("❌ Unknown error: $e");
      showMyToast(
        "ارسال رسید با خطا مواجه شد",
        context,
        backgroundColor: Colors.red,
      );
    }
  }

  void fetchDeviceId() async {
    deviceId = await getDeviceId();

    if (!mounted) return;
    setState(() {}); // optional, if you want to trigger rebuild

    fetchRenewalData(); // call only after deviceId is valid
  }

  void pickReceipt() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        receiptFile = File(file.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isRenewalLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SizedBox(
          height: 200, // 👈 Give it a height so it looks like a sheet
          child: Center(
            child: LoadingAnimationWidget.threeArchedCircle(
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      );
    }
    // ✅ Check for pending status and show message
    if (renewalData?['isPending'] == true) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const SizedBox(
          height: 150,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 30.0,
              ), // 👈 Add padding here
              child: Text(
                'بررسی رسید شما ممکن است تا ۲۴ ساعت طول بکشد. لطفاً شکیبا باشید.',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            if (serverMessage != null &&
                serverMessage != "خوش آمدید!" &&
                !messageDismissed)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF56A6E7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: Text(
                          serverMessage!,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 15, // ✅ updated per earlier request
                            color: Colors.white,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          setState(() => messageDismissed = true);

                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final lastDomain = prefs.getString(
                              'last_working_domain',
                            );

                            if (lastDomain == null) {
                              debugPrint("❌ No last working domain saved");
                              showMyToast(
                                "دامنه معتبر یافت نشد",
                                context,
                                backgroundColor: Colors.red,
                              );
                              setState(() => isRenewalLoading = false);
                              return;
                            }

                            if (deviceId == null) {
                              showMyToast(
                                "شناسه دستگاه یافت نشد",
                                context,
                                backgroundColor: Colors.red,
                              );
                              setState(() => isRenewalLoading = false);
                              return;
                            }

                            final dio = Dio(
                              BaseOptions(
                                connectTimeout: const Duration(seconds: 5),
                                receiveTimeout: const Duration(seconds: 5),
                              ),
                            );

                            await dio.post(
                              'http://$lastDomain/api/message/read',
                              data: {'deviceId': deviceId},
                              options: Options(
                                headers: {'Content-Type': 'application/json'},
                              ),
                            );
                          } on DioException catch (e) {
                            debugPrint(
                              "❌ Dio error on message read: ${e.message}",
                            );
                            showMyToast(
                              "خطا در ارتباط با سرور پیام",
                              context,
                              backgroundColor: Colors.red,
                            );
                          } catch (e) {
                            debugPrint("❌ Unexpected error: $e");
                            showMyToast(
                              "خطای نامشخص در مخفی‌سازی پیام",
                              context,
                              backgroundColor: Colors.red,
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(
                          "باشه",
                          style: TextStyle(fontSize: 18), // ✅ optional
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Tiers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  'در حساب شما $remainingGB گیگابایت و $remainingDays روز مانده\nچقدر به حسابتون اضافه بشه؟',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 15),
            PackageSelector(
              pricePerDay: serverProvidedDayPrice,
              pricePerGB: serverProvidedGbPrice,
              onChanged: (d, g) {
                setState(() {
                  selectedDays = d;
                  selectedGB = g;
                });
              },
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  'لطفاً مبلغ ${formatWithSpaces(selectedDays.toInt() * serverProvidedDayPrice + selectedGB.toInt() * serverProvidedGbPrice)} تومان کارت به کارت کنید.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 50),

            GestureDetector(
              onTap: pickReceipt,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    // 📤 Upload/Preview Container
                    Expanded(
                      flex: 1,
                      child: Stack(
                        children: [
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: receiptFile != null
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFF56A6E7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 35,
                              vertical: 15,
                            ),
                            child: Builder(
                              builder: (context) {
                                if (receiptFile == null) {
                                  isImageUnsupported = false;
                                  return const Text(
                                    'برای بارگذاری رسید کلیک کنید',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.center,
                                  );
                                }

                                if (receiptFile!.path.toLowerCase().endsWith(
                                  '.svg',
                                )) {
                                  isImageUnsupported = true;
                                  return const Text(
                                    'فرمت تصویر پشتیبانی نمی‌شود',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.center,
                                  );
                                }

                                isImageUnsupported = false;
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    receiptFile!,
                                    height: 300,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Text(
                                        'نمایش تصویر با خطا مواجه شد',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                        ),
                                        textDirection: TextDirection.rtl,
                                        textAlign: TextAlign.center,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),

                          // ❌ Close icon
                          if (receiptFile != null)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    receiptFile = null;
                                    isImageUnsupported = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(153),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 📋 Copy Card Number
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: renewalData?['cardNumber'] ?? '',
                            ),
                          );
                          // showMyToast(...);
                        },
                        child: Stack(
                          clipBehavior: Clip.none, // Allows overlap
                          children: [
                            // 📋 Main card container
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 35,
                              ),
                              child: Text(
                                (renewalData?['cardNumber'] as String?)
                                        ?.replaceAllMapped(
                                          RegExp(r'.{1,4}'),
                                          (match) => '${match.group(0)}\n',
                                        )
                                        .trim() ??
                                    '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),

                            // 🏷️ Overlapping label
                            Positioned(
                              top: -12, // overlaps above the main container
                              right: 40, // you can tweak this
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF56A6E7,
                                  ), // your accent color
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'شماره کارت',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textDirection: TextDirection.rtl,
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
            ),
            const SizedBox(height: 15),

            ElevatedButton(
              onPressed:
                  receiptFile == null ||
                      deviceId == null ||
                      isUploading ||
                      isImageUnsupported
                  ? null
                  : () async {
                      setState(() {
                        isUploading = true;
                      });

                      try {
                        final bytes = await receiptFile!.readAsBytes();
                        final base64Receipt = base64Encode(bytes);

                        final prefs = await SharedPreferences.getInstance();
                        final lastDomain = prefs.getString(
                          'last_working_domain',
                        );

                        if (lastDomain == null) {
                          throw Exception("No last working domain saved.");
                        }

                        await submitReceipt(context, base64Receipt, lastDomain);
                      } catch (e) {
                        debugPrint("❌ Upload error: $e");
                        showMyToast(
                          "خطای ارسال رسید",
                          context,
                          backgroundColor: Colors.red,
                        );
                      } finally {
                        setState(() => isUploading = false);
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => states.contains(WidgetState.disabled)
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFF56A6E7),
                ),
                minimumSize: WidgetStateProperty.all(
                  const Size(double.infinity, 50),
                ),
              ),
              child: isUploading
                  ? LoadingAnimationWidget.threeArchedCircle(
                      color: Colors.white,
                      size: 30,
                    )
                  : const Text(
                      'ارسال رسید',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
