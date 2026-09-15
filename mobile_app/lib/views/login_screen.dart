import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../main.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Admin Phone OTP & Registration State
  final TextEditingController _adminPhoneController = TextEditingController(text: '9876543210');
  final TextEditingController _adminOtpController = TextEditingController(text: '123456');
  final TextEditingController _adminOrgNameController = TextEditingController();
  final TextEditingController _adminOwnerNameController = TextEditingController();
  String _selectedOrgType = 'GYM';

  bool _otpSent = false;
  bool _isNewUser = false;
  bool _isLoading = false;
  String _errorMessage = '';

  final List<Map<String, String>> _orgTypes = [
    {'label': 'Gym & Fitness', 'value': 'GYM'},
    {'label': 'Hostel & PG', 'value': 'HOSTEL'},
    {'label': 'Tuition Centre', 'value': 'TUITION_CENTER'},
    {'label': 'Rental Building', 'value': 'RENTAL'},
    {'label': 'Academy', 'value': 'ACADEMY'},
  ];

  void _handleSendAdminOtp() async {
    final phone = _adminPhoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await ApiService.sendOtp(phone);
      if (res['otp'] != null) {
        setState(() {
          _otpSent = true;
          _isNewUser = res['isNewUser'] ?? false;
          _adminOtpController.text = res['otp'] ?? '123456';
          if (res['existingUser'] != null) {
            _adminOwnerNameController.text = res['existingUser']['name'] ?? '';
            _adminOrgNameController.text = res['existingUser']['orgName'] ?? '';
          }
        });
      } else {
        setState(() => _errorMessage = res['error'] ?? 'Could not send OTP');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Server error while sending OTP');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleVerifyAdminOtp() async {
    final phone = _adminPhoneController.text.trim();
    final otp = _adminOtpController.text.trim();

    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Please enter 6-digit OTP code');
      return;
    }

    if (_isNewUser) {
      if (_adminOrgNameController.text.trim().isEmpty || _adminOwnerNameController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please provide Facility Name and Owner Name to register');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final res = await ApiService.verifyOtp(
        phone: phone,
        otp: otp,
        orgName: _adminOrgNameController.text.trim(),
        adminName: _adminOwnerNameController.text.trim(),
        orgType: _selectedOrgType,
      );

      if (res['token'] != null) {
        await ApiService.saveSession(
          token: res['token'],
          role: res['user']?['role'] ?? 'ORG_ADMIN',
          orgId: res['organization']?['id'],
          orgName: res['organization']?['name'],
          userName: res['user']?['name'],
          phone: res['user']?['phone'],
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const MainNavigationScreen()),
          );
        }
      } else {
        setState(() => _errorMessage = res['error'] ?? 'Verification failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not complete login/registration');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.trending_up_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'RentTrack',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gym, Academy, PG & Tenant Management',
                  style: TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
                const SizedBox(height: 32),

                if (_errorMessage.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Facility Admin Phone OTP & Registration Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FACILITY ADMIN LOGIN',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your mobile number to sign in or register your business.',
                        style: TextStyle(color: AppColors.slate400, fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      const Text('Admin Mobile Number', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _adminPhoneController,
                        enabled: !_otpSent,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter 10-digit mobile number',
                          hintStyle: const TextStyle(color: AppColors.slate500),
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.slate400),
                          suffixIcon: _otpSent
                              ? TextButton(
                                  onPressed: () => setState(() {
                                    _otpSent = false;
                                    _isNewUser = false;
                                  }),
                                  child: const Text('Change', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_otpSent) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('6-Digit OTP Code', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                              child: const Text('Demo OTP: 123456', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _adminOtpController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_clock_rounded, color: AppColors.slate400),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_isNewUser) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('First-Time Facility Registration', style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                SizedBox(height: 2),
                                Text('Please provide your facility and owner details to get started.', style: TextStyle(color: AppColors.slate400, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Facility / Business Name *', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _adminOrgNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'e.g., Apex Gym & Fitness',
                              hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 13),
                              prefixIcon: const Icon(Icons.business_rounded, color: AppColors.slate400),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Owner / Admin Name *', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _adminOwnerNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'e.g., Alex Johnson',
                              hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 13),
                              prefixIcon: const Icon(Icons.person_rounded, color: AppColors.slate400),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Facility Category', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedOrgType,
                                isExpanded: true,
                                dropdownColor: AppColors.surface,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                items: _orgTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type['value'],
                                    child: Text(type['label']!),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedOrgType = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isLoading ? null : _handleVerifyAdminOtp,
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    _isNewUser ? 'Complete Registration & Login' : 'Verify OTP & Login',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isLoading ? null : _handleSendAdminOtp,
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Send OTP Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const OnboardingScreen()),
                    );
                  },
                  child: const Text(
                    'View App Features & Setup Guide →',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


