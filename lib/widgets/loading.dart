import 'package:dashed_circular_progress_bar/dashed_circular_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoadingProgressWidget extends StatefulWidget {
  final String loadingMessage;
  final ValueNotifier<double> progressNotifier;

  const LoadingProgressWidget({
    super.key,
    required this.loadingMessage,
    required this.progressNotifier,
  });

  @override
  State<LoadingProgressWidget> createState() => _LoadingProgressWidgetState();
}

class _LoadingProgressWidgetState extends State<LoadingProgressWidget> {
  bool showMainUI = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() => showMainUI = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!showMainUI && widget.loadingMessage != 'اینترنت متصل نیست') {
      return Column(
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
          Center(
            child: LoadingAnimationWidget.threeArchedCircle(
              color: Colors.white,
              size: 60,
            ),
          ),
        ],
      );
    }

    return Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: Text(
            widget.loadingMessage,
            style: const TextStyle(fontSize: 20, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 30),

        // 👇 Conditional display
        if (widget.loadingMessage == 'بررسی اتصال اینترنت')
          Center(
            child: LoadingAnimationWidget.threeArchedCircle(
              color: Colors.white,
              size: 60,
            ),
          ),
        if (widget.loadingMessage != 'خطا در دریافت اطلاعات' &&
            widget.loadingMessage != 'اینترنت متصل نیست' &&
            widget.loadingMessage != 'بررسی اتصال اینترنت')
          Center(
            child: ValueListenableBuilder<double>(
              valueListenable: widget.progressNotifier,
              builder: (context, value, _) {
                return DashedCircularProgressBar.square(
                  dimensions: 60,
                  progress: value,
                  maxProgress: 360,
                  startAngle: -27.5,
                  foregroundColor: const Color(0xFF56A6E7),
                  backgroundColor: const Color(0xffeeeeee),
                  foregroundStrokeWidth: 6,
                  backgroundStrokeWidth: 6,
                  foregroundGapSize: 20,
                  foregroundDashSize: 20,
                  backgroundGapSize: 20,
                  backgroundDashSize: 20,
                  animation: false,
                );
              },
            ),
          ),
      ],
    );
  }
}
