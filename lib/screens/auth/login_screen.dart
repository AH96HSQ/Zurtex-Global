import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/animated_dots_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  // Step 1: Email input
  // Step 2: OTP input (for both login and register)
  int _currentStep = 1;
  bool _isExistingUser = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Please enter a valid email';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await AuthService.checkEmail(email);

    setState(() {
      _isLoading = false;
    });

    if (result.containsKey('error')) {
      setState(() {
        _errorMessage = result['error'];
      });
      return;
    }

    if (result['exists'] == true && result['otpSent'] == true) {
      // Existing user - OTP already sent automatically
      setState(() {
        _isExistingUser = true;
        _currentStep = 2;
      });
      _showMessage('Verification code sent to your email');
    } else if (result['exists'] == false) {
      // New user - need to request OTP first
      setState(() {
        _isExistingUser = false;
        _currentStep = 2;
      });
      // Automatically request OTP for new user
      await _handleRequestOTP();
    }
  }

  Future<void> _handleRequestOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await AuthService.requestOTP(_emailController.text.trim());

    setState(() {
      _isLoading = false;
    });

    if (result.containsKey('error')) {
      setState(() {
        _errorMessage = result['error'];
      });
      return;
    }

    if (result['success'] == true) {
      _showMessage('Verification code sent to your email');
      setState(() {});
    }
  }

  Future<void> _handleLoginSubmit() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await AuthService.login(_emailController.text.trim(), otp);

    setState(() {
      _isLoading = false;
    });

    if (result.containsKey('error')) {
      setState(() {
        _errorMessage = result['error'];
      });
      return;
    }

    if (result['success'] == true) {
      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  Future<void> _handleRegisterSubmit() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await AuthService.register(
      _emailController.text.trim(),
      otp,
    );

    setState(() {
      _isLoading = false;
    });

    if (result.containsKey('error')) {
      setState(() {
        _errorMessage = result['error'];
      });
      return;
    }

    if (result['success'] == true) {
      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEmailStep(Color textColor, Color subtextColor) {
    final inputBgColor = const Color(
      0xFF2A2A2A,
    ); // Slightly lighter than background
    final borderColor = Colors.white.withValues(alpha: .1);
    final focusBorderColor = const Color(0xFF9700FF); // Theme color
    final buttonBgColor = const Color(0xFF9700FF); // Theme color
    final buttonTextColor = Colors.white;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Welcome',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: TextStyle(color: subtextColor),
            filled: true,
            fillColor: inputBgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusBorderColor, width: 2),
            ),
          ),
          onSubmitted: (_) => _handleEmailSubmit(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleEmailSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBgColor,
              foregroundColor: buttonTextColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        buttonTextColor,
                      ),
                    ),
                  )
                : const Text(
                    'Continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginStep(Color textColor, Color subtextColor) {
    final inputBgColor = const Color(
      0xFF2A2A2A,
    ); // Slightly lighter than background
    final borderColor = Colors.white.withValues(alpha: .1);
    final focusBorderColor = const Color(0xFF9700FF); // Theme color
    final buttonBgColor = const Color(0xFF9700FF); // Theme color
    final buttonTextColor = Colors.white;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Login',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 48),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Verification Code',
            labelStyle: TextStyle(color: subtextColor),
            filled: true,
            fillColor: inputBgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusBorderColor, width: 2),
            ),
          ),
          onSubmitted: (_) => _handleLoginSubmit(),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 1;
                      _otpController.clear();
                      _errorMessage = '';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLoginSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBgColor,
                    foregroundColor: buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              buttonTextColor,
                            ),
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterStep(Color textColor, Color subtextColor) {
    final inputBgColor = const Color(
      0xFF2A2A2A,
    ); // Slightly lighter than background
    final borderColor = Colors.white.withValues(alpha: .1);
    final focusBorderColor = const Color(0xFF9700FF); // Theme color
    final buttonBgColor = const Color(0xFF9700FF); // Theme color
    final buttonTextColor = Colors.white;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Register',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 48),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Verification Code',
            labelStyle: TextStyle(color: subtextColor),
            filled: true,
            fillColor: inputBgColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusBorderColor, width: 2),
            ),
          ),
          onSubmitted: (_) => _handleRegisterSubmit(),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentStep = 1;
                      _otpController.clear();
                      _errorMessage = '';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegisterSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBgColor,
                    foregroundColor: buttonTextColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              buttonTextColor,
                            ),
                          ),
                        )
                      : const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = const Color(0xFF212121); // App background color
    final textColor = Colors.white;
    final subtextColor = Colors.white70;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: AnimatedDotsBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _currentStep == 1
                          ? _buildEmailStep(textColor, subtextColor)
                          : _isExistingUser
                          ? _buildLoginStep(textColor, subtextColor)
                          : _buildRegisterStep(textColor, subtextColor),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: .3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
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
            ),
          ),
        ),
      ),
    );
  }
}
