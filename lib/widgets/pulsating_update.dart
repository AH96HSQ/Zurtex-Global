import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateBanner extends StatefulWidget {
  final String currentVersion;
  final String? latestVersion;
  final String? updateUrl;

  const UpdateBanner({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateUrl,
  });

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _controller2;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..repeat(reverse: true);

    _controller2 = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _colorAnimation = ColorTween(
      begin: const Color(0xFF9700FF),
      end: Colors.green,
    ).animate(CurvedAnimation(parent: _controller2, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsUpdate =
        widget.latestVersion != null &&
        widget.latestVersion!.isNotEmpty &&
        widget.currentVersion.isNotEmpty &&
        widget.latestVersion!.compareTo(widget.currentVersion) > 0;
    if (!needsUpdate) return const SizedBox.shrink();

    return Center(
      child: GestureDetector(
        onTap: () {
          if (widget.updateUrl?.isNotEmpty == true) {
            launchUrl(
              Uri.parse(widget.updateUrl!),
              mode: LaunchMode.externalApplication,
            );
          }
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 310,
              height: 65,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _colorAnimation.value ?? const Color(0xFF9700FF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                'Download New Version',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
