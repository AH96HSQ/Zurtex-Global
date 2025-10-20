import 'dart:async';
import 'package:flutter/material.dart';

class LongPressConfirmButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  final String label;
  final IconData icon;

  const LongPressConfirmButton({
    super.key,
    required this.onConfirmed,
    required this.label,
    required this.icon,
  });

  @override
  State<LongPressConfirmButton> createState() => _LongPressConfirmButtonState();
}

class _LongPressConfirmButtonState extends State<LongPressConfirmButton>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  Timer? _timer;
  bool _confirmed = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
          lowerBound: 1,
          upperBound: 1.02,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _pulseController.reverse();
          } else if (status == AnimationStatus.dismissed) {
            _pulseController.forward();
          }
        });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progress = 0;
    _confirmed = false;

    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        _progress += 0.01;
        if (_progress >= 1) {
          _progress = 1;
          _timer?.cancel();
          _confirmed = true;
          _pulseController.forward(); // Start pulsating
          widget.onConfirmed();
        }
      });
    });
  }

  void _cancelProgress() {
    _timer?.cancel();
    setState(() {
      _progress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = _confirmed ? Colors.redAccent : Colors.red;

    return GestureDetector(
      onLongPressStart: (_) => _startProgress(),
      onLongPressEnd: (_) => _cancelProgress(),
      child: ScaleTransition(
        scale: _confirmed
            ? _pulseController
            : const AlwaysStoppedAnimation(1.0),
        child: Stack(
          children: [
            Container(
              height: 70,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: buttonColor,
              ),
            ),
            if (!_confirmed)
              AnimatedContainer(
                duration: const Duration(milliseconds: 30),
                height: 70,
                width: MediaQuery.of(context).size.width * _progress,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF56A6E7),
                ),
              ),
            SizedBox(
              height: 70,
              width: double.infinity,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _confirmed ? 'درخواست لغو ارسال شد' : widget.label,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
