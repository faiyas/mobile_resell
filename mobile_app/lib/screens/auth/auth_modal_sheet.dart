import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../../utils/contact_launcher.dart';

class AuthModalSheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const AuthModalSheet({super.key, required this.onSuccess});

  @override
  State<AuthModalSheet> createState() => _AuthModalSheetState();
}

class _AuthModalSheetState extends State<AuthModalSheet> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Modes: 'LOGIN', 'REGISTER', 'FORGOT_PASSWORD'
  String _mode = 'LOGIN';
  bool _loading = false;
  String _error = '';

  // Fallback to Admin state
  bool _fallbackToAdmin = false;
  String _adminPhone = '9025232453';

  // OTP state
  bool _otpSent = false;
  int _resendCountdown = 0;
  Timer? _timer;

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _timer?.cancel();
    _identifierController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = '';
      _fallbackToAdmin = false;
    });

    try {
      await _api.login(
        _identifierController.text.trim(),
        _passwordController.text,
      );
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '').trim();
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleSendRegisterOtp() async {
    final phone = _phoneController.text.trim();
    final name = _fullNameController.text.trim();
    final pwd = _passwordController.text;

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name');
      return;
    }
    if (phone.length < 10) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number');
      return;
    }
    if (pwd.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters long');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _fallbackToAdmin = false;
    });

    final res = await _api.sendCustomerOtp(phone, purpose: 'REGISTRATION');
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'OTP sent to $phone'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _loading = false;
        _error = res['message'] ?? 'Unable to send OTP';
        _fallbackToAdmin = res['fallback_to_admin'] == true;
        _adminPhone = res['admin_phone'] ?? '9025232453';
      });
    }
  }

  Future<void> _handleVerifyRegister() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() => _error = 'Please enter the 6-digit code received on your phone');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _api.verifyRegisterCustomer(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        otpCode: otp,
      );
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        String msg = 'Registration failed';
        bool fallback = false;
        if (e is Map) {
          msg = e['detail'] ?? msg;
          fallback = e['fallback_to_admin'] == true;
          _adminPhone = e['admin_phone'] ?? _adminPhone;
        } else {
          msg = e.toString().replaceAll('Exception: ', '').trim();
        }
        setState(() {
          _error = msg;
          _fallbackToAdmin = fallback;
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleSendForgotOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Please enter your registered 10-digit mobile number');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _fallbackToAdmin = false;
    });

    final res = await _api.sendCustomerOtp(phone, purpose: 'PASSWORD_RESET');
    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Password reset code sent'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _loading = false;
        _error = res['message'] ?? 'Unable to send reset code';
        _fallbackToAdmin = res['fallback_to_admin'] == true;
        _adminPhone = res['admin_phone'] ?? '9025232453';
      });
    }
  }

  Future<void> _handleVerifyResetPassword() async {
    final otp = _otpController.text.trim();
    final newPwd = _newPasswordController.text;

    if (otp.length < 4) {
      setState(() => _error = 'Please enter the verification code');
      return;
    }
    if (newPwd.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _api.resetCustomerPassword(
        phone: _phoneController.text.trim(),
        otpCode: otp,
        newPassword: newPwd,
      );
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        String msg = 'Password reset failed';
        bool fallback = false;
        if (e is Map) {
          msg = e['detail'] ?? msg;
          fallback = e['fallback_to_admin'] == true;
          _adminPhone = e['admin_phone'] ?? _adminPhone;
        } else {
          msg = e.toString().replaceAll('Exception: ', '').trim();
        }
        setState(() {
          _error = msg;
          _fallbackToAdmin = fallback;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.96),
                const Color(0xFFF0FDF4).withOpacity(0.92),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: AppTheme.glassBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mode == 'REGISTER'
                                ? (_otpSent ? 'Verify Mobile Number' : 'Create Customer Account')
                                : _mode == 'FORGOT_PASSWORD'
                                    ? (_otpSent ? 'Enter Reset Code' : 'Reset Password')
                                    : 'Welcome to Dolly',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _mode == 'REGISTER'
                                ? (_otpSent ? 'Enter code sent to ${_phoneController.text.trim()}' : 'Verified registration with OTP')
                                : _mode == 'FORGOT_PASSWORD'
                                    ? 'Reset password using SMS OTP verification'
                                    : 'Sign in with your phone and password',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'SECURE',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Error Banner
                  if (_error.isNotEmpty)
                    GlassContainer(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error, style: TextStyle(color: Colors.red.shade900, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  // Fallback: Call Admin Card if SMS failed
                  if (_fallbackToAdmin)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade400, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.support_agent_rounded, color: Colors.amber.shade900, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'SMS Delivery Unavailable',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Don\'t worry! Our admin team can immediately verify and create your account directly over the phone without OTP.',
                            style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: Colors.white),
                              label: Text('Call Admin Desk (+91 $_adminPhone)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white)),
                              onPressed: () => ContactLauncher.callHotline(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ================= MODE 1: STANDARD LOGIN =================
                  if (_mode == 'LOGIN') ...[
                    TextFormField(
                      controller: _identifierController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number or Email *',
                        prefixIcon: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.85),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter mobile number or email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.85),
                      ),
                      validator: (v) => v == null || v.length < 4 ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _mode = 'FORGOT_PASSWORD';
                          _otpSent = false;
                          _error = '';
                          _fallbackToAdmin = false;
                        }),
                        child: const Text('Forgot Password?', style: TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton('Sign In', _loading ? null : _handleLogin),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _mode = 'REGISTER';
                          _otpSent = false;
                          _error = '';
                          _fallbackToAdmin = false;
                        }),
                        child: const Text('New to Dolly? Create Verified Account', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],

                  // ================= MODE 2: REGISTRATION WITH OTP =================
                  if (_mode == 'REGISTER') ...[
                    if (!_otpSent) ...[
                      TextFormField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryGreen),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number *',
                          prefixText: '+91 ',
                          counterText: '',
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Set Password (min 6 characters) *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildActionButton('Send Verification Code (OTP)', _loading ? null : _handleSendRegisterOtp),
                    ] else ...[
                      // OTP Input Step
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                        decoration: InputDecoration(
                          labelText: '6-Digit Verification Code',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _resendCountdown > 0 ? 'Resend code in ${_resendCountdown}s' : 'Didn\'t receive code?',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          TextButton(
                            onPressed: _resendCountdown > 0 || _loading ? null : _handleSendRegisterOtp,
                            child: const Text('Resend OTP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildActionButton('Verify & Complete Registration', _loading ? null : _handleVerifyRegister),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _mode = 'LOGIN';
                          _otpSent = false;
                          _error = '';
                          _fallbackToAdmin = false;
                        }),
                        child: const Text('Already have an account? Sign In', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],

                  // ================= MODE 3: FORGOT PASSWORD =================
                  if (_mode == 'FORGOT_PASSWORD') ...[
                    if (!_otpSent) ...[
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: 'Registered Mobile Number *',
                          prefixText: '+91 ',
                          counterText: '',
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildActionButton('Send Password Reset Code', _loading ? null : _handleSendForgotOtp),
                    ] else ...[
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                        decoration: InputDecoration(
                          labelText: '6-Digit Code',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'New Password *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildActionButton('Save New Password & Sign In', _loading ? null : _handleVerifyResetPassword),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _mode = 'LOGIN';
                          _otpSent = false;
                          _error = '';
                          _fallbackToAdmin = false;
                        }),
                        child: const Text('Remember password? Back to Sign In', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback? onPressed) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: AppTheme.primaryGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)),
      ),
    );
  }
}

