import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';

class AuthModalSheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const AuthModalSheet({super.key, required this.onSuccess});

  @override
  State<AuthModalSheet> createState() => _AuthModalSheetState();
}

class _AuthModalSheetState extends State<AuthModalSheet> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  bool _isRegister = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String _error = '';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _role = 'CUSTOMER';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      if (_isRegister) {
        await _api.register({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'full_name': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': _role,
        });
      } else {
        await _api.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
                Colors.white.withOpacity(0.95),
                const Color(0xFFF0FDF4).withOpacity(0.90),
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRegister ? 'Join Dolly' : 'Welcome to Dolly',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Doorstep gadget buyback & operations login',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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

                  if (_isRegister) ...[
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.85),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter full name' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number *',
                        prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryGreen),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.85),
                      ),
                      validator: (v) => v == null || v.trim().length < 10 ? 'Enter 10-digit number' : null,
                    ),
                    const SizedBox(height: 10),
                  ],

                  TextFormField(
                    controller: _emailController,
                    keyboardType: _isRegister ? TextInputType.emailAddress : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: _isRegister ? 'Email Address *' : 'Mobile Number or Email *',
                      prefixIcon: Icon(
                        _isRegister ? Icons.email_outlined : Icons.account_circle_outlined, 
                        color: AppTheme.primaryGreen
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return _isRegister ? 'Enter email address' : 'Enter mobile number or email';
                      }
                      final val = v.trim();
                      if (_isRegister) {
                        if (!val.contains('@')) return 'Enter valid email address';
                      } else {
                        final isPhone = RegExp(r'^[0-9]{10}$').hasMatch(val);
                        final isEmail = val.contains('@');
                        if (!isPhone && !isEmail) {
                          return 'Enter valid 10-digit mobile or email';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.85),
                    ),
                    validator: (v) => v == null || v.length < 4 ? 'Enter password' : null,
                  ),
                  const SizedBox(height: 18),

                  Container(
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
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(_isRegister ? 'Create Account' : 'Sign In', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _isRegister = !_isRegister),
                      child: Text(
                        _isRegister ? 'Already have an account? Sign In' : 'New to Dolly? Create Account',
                        style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
