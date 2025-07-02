// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:zurtex/constants/api_config.dart';
import 'package:zurtex/models/vpn_account.dart';
import 'package:zurtex/screens/home_screen.dart';
import 'package:zurtex/utils/toast_utils.dart';
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
  Map<String, dynamic>? selectedPackage;
  File? receiptFile;
  String? deviceId;
  bool isRenewalLoading = true;
  Map<String, dynamic>? renewalData;
  String? serverMessage;
  bool messageDismissed = false;

  bool isUploading = false;
  double uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    fetchDeviceId();
  }

  Future<void> fetchRenewalData() async {
    try {
      final res = await Dio().get(
        'http://${ApiConfig.baseUrl}/api/renewal',
        queryParameters: {'deviceId': deviceId},
      );

      if (res.statusCode == 200) {
        final data = res.data;

        setState(() {
          renewalData = data;
          serverMessage = data['message']; // ✅ store the message
          messageDismissed = false; // ✅ show it
          isRenewalLoading = false;
        });
      } else {
        setState(() => isRenewalLoading = false);
        showMyToast(
          "در حال حاضر تمدید مسدود است",
          context,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      showMyToast("مشکل در ارتباط", context, backgroundColor: Colors.red);
      setState(() {
        isRenewalLoading = false;
      });
      Navigator.of(context).pop();
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
    final List<Map<String, dynamic>> tierPackages =
        List<Map<String, dynamic>>.from(
          renewalData?['packages']?[selectedTier] ?? [],
        );
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
                            await Dio().post(
                              'http://${ApiConfig.baseUrl}/api/message/read',
                              data: {'deviceId': deviceId},
                              options: Options(
                                headers: {'Content-Type': 'application/json'},
                              ),
                            );
                          } catch (e) {
                            showMyToast(
                              "خطا در مخفی‌سازی پیام",
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              textDirection: TextDirection.rtl, // ✅ force LTR layout

              children:
                  (renewalData?['packages']?.keys.toList().cast<String>() ?? [])
                      .map<Widget>((tier) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: SizedBox(
                                width: double.infinity,
                                child: Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Text(
                                    tier,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 0,
                              ),
                              selected: selectedTier == tier,
                              selectedColor: const Color(0xFF56A6E7),
                              backgroundColor: const Color(0xFF2A2A2A),
                              showCheckmark: false,
                              side: BorderSide.none,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (_) {
                                setState(() {
                                  selectedTier = tier;
                                  selectedPackage = null;
                                });
                              },
                            ),
                          ),
                        );
                      })
                      .toList(),
            ),
            const SizedBox(height: 10),

            // Packages
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // ensures full width
              children: tierPackages.map((pkg) {
                final isSelected = selectedPackage?['label'] == pkg['label'];
                final int gb = pkg['gb'] ?? 0;

                return InkWell(
                  onTap: () => setState(() => selectedPackage = pkg),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF56A6E7)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl, // full RTL layout
                      children: [
                        // 👈 Left side (in RTL): gigabyte amount
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            '${gb.toString().padLeft(3, '0')} گیگابایت',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                            ),
                          ),
                        ),

                        // 👉 Right side (in RTL): price
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            '${pkg['label'] ?? ''} هزار تومان',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            GestureDetector(
              onTap: selectedPackage == null ? null : pickReceipt,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ), // 👈 adjust as needed
                child: Row(
                  children: [
                    // 📤 Upload/Preview Container (flex = 1)
                    Expanded(
                      flex: 1,
                      child: Stack(
                        children: [
                          // 🟦 Main container with image or text
                          Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color:
                                  selectedPackage == null || receiptFile != null
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFF56A6E7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 35,
                              vertical: 15,
                            ),
                            child:
                                receiptFile != null && selectedPackage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      receiptFile!,
                                      height: 300,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : Text(
                                    selectedPackage == null
                                        ? 'اول یک بسته را انتخاب کنید'
                                        : 'برای بارگذاری رسید کلیک کنید',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.center,
                                  ),
                          ),

                          // ❌ Close icon positioned over the container (top-right)
                          if (receiptFile != null && selectedPackage != null)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    receiptFile = null;
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
                    // 📋 Copy Card Number Container
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
                        child: Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 35),
                          child: Text(
                            (renewalData?['cardNumber'] as String?)
                                    ?.replaceAllMapped(
                                      RegExp(r'.{1,4}'),
                                      (match) => '${match.group(0)}\n',
                                    )
                                    .trim() ??
                                '',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 18),
                            textDirection: TextDirection.rtl,
                          ),
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
                  selectedPackage == null ||
                      receiptFile == null ||
                      deviceId == null ||
                      isUploading
                  ? null
                  : () async {
                      setState(() {
                        isUploading = true;
                        uploadProgress = 0;
                      });

                      try {
                        final bytes = await receiptFile!.readAsBytes();
                        final base64Receipt = base64Encode(bytes);

                        final dio = Dio();
                        final response = await dio.post(
                          'http://${ApiConfig.baseUrl}/api/receipt',
                          data: {
                            "price": selectedPackage?['label'],
                            "deviceId": deviceId,
                            "receiptData": base64Receipt,
                            "gigabyte": selectedPackage?['gb'], // ✅ Correct key
                            "durationInDays":
                                selectedPackage?['days'], // ✅ Add this key if it exists
                          },
                          onSendProgress: (sent, total) {
                            if (total > 0) {
                              setState(() {
                                uploadProgress = sent / total;
                              });
                            }
                          },
                          options: Options(
                            headers: {'Content-Type': 'application/json'},
                          ),
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
                              messages: widget
                                  .account
                                  .messages, // ✅ keep existing messages
                            ),
                          );

                          Navigator.of(
                            context,
                          ).pop(); // ✅ closes the bottom sheet
                        } else {
                          showMyToast(
                            "خطا در ارسال رسید",
                            context,
                            backgroundColor: Colors.red,
                          );
                        }
                      } catch (e) {
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
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  states,
                ) {
                  if (states.contains(WidgetState.disabled)) {
                    return const Color(0xFF2A2A2A);
                  }
                  return const Color(0xFF56A6E7);
                }),
                minimumSize: WidgetStateProperty.all(
                  const Size(double.infinity, 50),
                ),
              ),
              child: isUploading
                  ? LinearProgressIndicator(
                      value: uploadProgress,
                      color: Color(0xFF56A6E7),
                      backgroundColor: Colors.white24,
                    )
                  : const Text(
                      'ثبت نهایی',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
