import 'package:flutter/material.dart';

class PasswordProtectedTab extends StatefulWidget {
  final Widget child;
  final String password;

  const PasswordProtectedTab({
    super.key,
    required this.child,
    this.password = '56746671sbbB',
  });

  @override
  State<PasswordProtectedTab> createState() => _PasswordProtectedTabState();
}

class _PasswordProtectedTabState extends State<PasswordProtectedTab> {
  final _controller = TextEditingController();
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkPassword);
  }

  void _checkPassword() {
    if (_controller.text == widget.password && !_unlocked) {
      setState(() => _unlocked = true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkPassword);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'این روش برای افراد محدودی است و نیاز به رمز دارد',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48, // or any fixed height
            child: TextField(
              controller: _controller,
              obscureText: true,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'رمز ورود',
                hintStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
