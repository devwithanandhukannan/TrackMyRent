import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../main.dart';
import 'profile_completion_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Mode: 0 = Register New Facility, 1 = Existing Owner Sign In
  int _tabMode = 0;

  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String _errorMessage = '';
  int _countdown = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
    _otpController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _phoneController.dispose();
    _orgNameController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number.');
      return;
    }

    if (_tabMode == 0) {
      if (_ownerNameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter your Full Name.');
        return;
      }
      if (_orgNameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please enter your Property / Facility Name.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await ApiService.sendOtp(phone);
      if (res['success'] == true) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        _startCountdown();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['error'] ?? 'Failed to send OTP. Please try again.';
        });
      }
    } catch (_) {
      // Local dev fallback
      setState(() {
        _otpSent = true;
        _isLoading = false;
      });
      _startCountdown();
    }
  }

  Future<void> _handleVerifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim().isEmpty ? '00000' : _otpController.text.trim();
    final name = _ownerNameController.text.trim();
    final orgName = _orgNameController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await ApiService.verifyOtp(
        phone: phone,
        otp: otp,
        adminName: name.isNotEmpty ? name : null,
        orgName: orgName.isNotEmpty ? orgName : null,
      );

      if (res['token'] != null) {
        final finalOrgName = res['organization']?['name'] ?? orgName;
        final finalUserName = res['user']?['name'] ?? name;

        await ApiService.saveSession(
          token: res['token'],
          role: res['user']?['role'] ?? 'ORG_ADMIN',
          orgId: res['organization']?['id'],
          orgName: finalOrgName,
          userName: finalUserName,
          phone: res['user']?['phone'] ?? phone,
        );

        final isCompleted = await ApiService.isProfileCompleted();

        if (mounted) {
          if (_tabMode == 0 || !isCompleted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (ctx) => ProfileCompletionScreen(
                  phone: phone,
                  initialName: finalUserName,
                  initialOrgName: finalOrgName,
                ),
              ),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (ctx) => const MainNavigationScreen()),
            );
          }
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res['error'] ?? 'Invalid verification code. Please check and retry.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not connect to server. Please check your network.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Atmospheric Emerald Brand Logo
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondaryContainer.withValues(alpha: 0.35),
                        ),
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.apartment_rounded, size: 38, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // App Title & Tagline
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Trusted Property OS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'RentTrack',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Effortless Rent & Member Management',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Feature Pill Badges
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildFeatureBadge(Icons.bolt_rounded, 'Auto Billing'),
                      _buildFeatureBadge(Icons.chat_bubble_outline_rounded, '1-Tap WhatsApp'),
                      _buildFeatureBadge(Icons.account_balance_rounded, 'Direct UPI'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Mode Selector Tabs (Register vs Sign In)
                  if (!_otpSent)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _tabMode = 0;
                                _errorMessage = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _tabMode == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _tabMode == 0
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Register Property',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _tabMode == 0 ? FontWeight.w700 : FontWeight.w600,
                                    color: _tabMode == 0 ? AppColors.onSurface : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _tabMode = 1;
                                _errorMessage = '';
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _tabMode == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _tabMode == 1
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Existing Sign In',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _tabMode == 1 ? FontWeight.w700 : FontWeight.w600,
                                    color: _tabMode == 1 ? AppColors.onSurface : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Elevated White Card (Main Form)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Registration extra fields
                        if (_tabMode == 0 && !_otpSent) ...[
                          const Text(
                            'Your Full Name',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _ownerNameController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Anandhu Kannan',
                              hintStyle: const TextStyle(fontSize: 14, color: AppColors.outline),
                              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.primary),
                              filled: true,
                              fillColor: AppColors.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Facility / Business Name',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _orgNameController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Royal PG Hostels or Iron Gym',
                              hintStyle: const TextStyle(fontSize: 14, color: AppColors.outline),
                              prefixIcon: const Icon(Icons.business_outlined, size: 20, color: AppColors.primary),
                              filled: true,
                              fillColor: AppColors.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Phone Number Input
                        const Text(
                          'Mobile Number',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  children: [
                                    Text('🇮🇳', style: TextStyle(fontSize: 16)),
                                    SizedBox(width: 4),
                                    Text(
                                      '+91',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  enabled: !_otpSent,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: AppColors.onSurface,
                                  ),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    hintText: '98450 12345',
                                    hintStyle: TextStyle(fontSize: 14, color: AppColors.outline),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              if (_otpSent)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                  onPressed: () => setState(() => _otpSent = false),
                                ),
                            ],
                          ),
                        ),

                        // OTP Section
                        if (_otpSent) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enter Passcode',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Code sent to WhatsApp & SMS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryContainer.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(radius: 3, backgroundColor: AppColors.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Sent',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // PIN Input
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 10,
                              color: AppColors.primary,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '••••••',
                              hintStyle: const TextStyle(letterSpacing: 8, color: AppColors.outline),
                              filled: true,
                              fillColor: AppColors.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Timer & Resend
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 14, color: AppColors.outline),
                                  const SizedBox(width: 4),
                                  Text(
                                    _countdown > 0 ? 'Resend code in 0:${_countdown.toString().padLeft(2, '0')}s' : 'Code expired',
                                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _countdown == 0 ? _handleSendOtp : null,
                                child: Text(
                                  'Resend',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _countdown == 0 ? AppColors.primary : AppColors.outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Error Message
                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.appleRedBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.appleRed),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(fontSize: 12, color: AppColors.appleRed, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : (_otpSent ? _handleVerifyOtp : _handleSendOtp),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _otpSent ? 'Verify & Continue' : 'Get Verification Code',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                          ),
                        ),
                      ],
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

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
