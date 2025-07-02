import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void showMyToast(
  String msg,
  BuildContext context, {
  Color backgroundColor = Colors.black87,
}) {
  final fToast = FToast();
  fToast.init(context);

  fToast.showToast(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: backgroundColor,
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          msg,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    ),
    gravity: ToastGravity.BOTTOM,
    toastDuration: const Duration(seconds: 5),
  );
}
