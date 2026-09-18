import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // Mode: 0 = Register New Facility, 1 = Existing Tenant Sign In
  int _tabMode = 0;

  // Controllers for Basic Tenant Details
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _otpController = TextEditingController(text: '00000');

  String _selectedOrgType = 'GYM';
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';

  final List<Map<String, String>> _orgTypes = [
    {'label': 'Gym & Fitness Center', 'value': 'GYM'},
    {'label': 'Hostel & PG Living', 'value': 'HOSTEL'},
    {'label': 'Tuition & Coaching Centre', 'value': 'TUITION_CENTER'},
    {'label': 'Rental Building / Property', 'value': 'RENTAL'},
    {'label': 'Academy & Sports Club', 'value': 'ACADEMY'},
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _phoneController.dispose();
    _orgNameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ─── Verification & Submission ─────────────────────────────────────────────

  Future<void> _handleTenantSubmit() async {
    setState(() {
      _errorMessage = '';
      _successMessage = '';
    });

    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim().isEmpty ? '00000' : _otpController.text.trim();
    final name = _ownerNameController.text.trim();
    final orgName = _orgNameController.text.trim();

    // 1. Mandatory 10-digit Phone Validation
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your 10-digit mobile number.');
      return;
    }
    if (phone.length != 10) {
      setState(() => _errorMessage = 'Mobile number must be exactly 10 digits (currently ${phone.length}/10).');
      return;
    }

    // 2. Mandatory Basic Details Check for Registration
    if (_tabMode == 0) {
      if (name.isEmpty) {
        setState(() => _errorMessage = 'Please enter your Full Name.');
        return;
      }
      if (orgName.isEmpty) {
        setState(() => _errorMessage = 'Please enter your Organisation / Facility Name.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.verifyOtp(
        phone: phone,
        otp: otp,
        adminName: name.isNotEmpty ? name : null,
        orgName: orgName.isNotEmpty ? orgName : null,
        orgType: _selectedOrgType,
      );

      if (res['token'] != null) {
        final finalOrgName = res['organization']?['name'] ?? orgName;
        final finalUserName = res['user']?['name'] ?? name;

        // Verify that the user actually has basic details registered
        if ((finalOrgName == null || finalOrgName.toString().trim().isEmpty) ||
            (finalUserName == null || finalUserName.toString().trim().isEmpty)) {
          setState(() {
            _tabMode = 0; // Switch to register tab
            _errorMessage = 'Basic details missing. Please enter your Name and Organisation Name.';
          });
          return;
        }

        await ApiService.saveSession(
          token: res['token'],
          role: res['user']?['role'] ?? 'ORG_ADMIN',
          orgId: res['organization']?['id'],
          orgName: finalOrgName,
          userName: finalUserName,
          phone: res['user']?['phone'] ?? phone,
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const MainNavigationScreen()),
          );
        }
      } else {
        final err = res['error'] ?? 'Authentication failed';
        if (err.toLowerCase().contains('name') || err.toLowerCase().contains('basic')) {
          setState(() {
            _tabMode = 0; // Switch to registration tab so user can complete basic details
            _errorMessage = err;
          });
        } else {
          setState(() => _errorMessage = err);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not connect to server. Please check your network.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── 10-Column Phone Number Display Widget ──────────────────────────────────
  Widget _build10ColumnPhoneIndicator(String phone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '10-Digit Mobile Number (India)',
              style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: phone.length == 10
                    ? const Color(0xFF059669).withValues(alpha: 0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: phone.length == 10 ? const Color(0xFF059669) : Colors.transparent,
                ),
              ),
              child: Text(
                '${phone.length} / 10 Digits',
                style: TextStyle(
                  color: phone.length == 10 ? const Color(0xFF10B981) : AppColors.slate400,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Text Field with +91 prefix
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter 10-digit number',
            hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 14, letterSpacing: 0),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: const Text(
                '+91',
                style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Visual 10 Columns Row (Directly implements "phonenumber show the 10 col")
        Row(
          children: List.generate(10, (index) {
            final hasDigit = index < phone.length;
            final digitChar = hasDigit ? phone[index] : '';
            final isCurrent = index == phone.length;

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 9 ? 4.0 : 0.0),
                height: 38,
                decoration: BoxDecoration(
                  color: hasDigit
                      ? const Color(0xFF059669).withValues(alpha: 0.25)
                      : (isCurrent ? Colors.white12 : AppColors.background),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasDigit
                        ? const Color(0xFF10B981)
                        : (isCurrent ? const Color(0xFF38BDF8) : Colors.white10),
                    width: hasDigit || isCurrent ? 1.5 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  hasDigit ? digitChar : '${index + 1}',
                  style: TextStyle(
                    color: hasDigit
                        ? Colors.white
                        : (isCurrent ? const Color(0xFF38BDF8) : Colors.white24),
                    fontSize: hasDigit ? 15 : 10,
                    fontWeight: hasDigit ? FontWeight.w900 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.apartment_rounded, size: 38, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text(
                  'RentTrack',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Facility Management & Rental Payment System',
                  style: TextStyle(fontSize: 12, color: AppColors.slate400),
                ),
                const SizedBox(height: 24),

                // Error Message Alert
                if (_errorMessage.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Success Message Alert
                if (_successMessage.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage,
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Segmented Tabs: Register vs Sign In
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabMode == 0 ? const Color(0xFF059669) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Register Facility',
                              style: TextStyle(
                                color: _tabMode == 0 ? Colors.white : AppColors.slate400,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tabMode == 1 ? const Color(0xFF059669) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: _tabMode == 1 ? Colors.white : AppColors.slate400,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Main Form Card
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
                      // Header Text
                      Text(
                        _tabMode == 0 ? 'TENANT FACILITY REGISTRATION' : 'TENANT SIGN IN',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tabMode == 0
                            ? 'Register your basic details (Name, 10-digit Phone, Organisation Name) to manage your services.'
                            : 'Enter your registered 10-digit phone number to sign in to your facility.',
                        style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      // Field 1: Name (Required in Registration Mode)
                      if (_tabMode == 0) ...[
                        const Text('Owner / Admin Name *', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _ownerNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'e.g., Anandhu Kannan',
                            hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 13),
                            prefixIcon: const Icon(Icons.person_rounded, color: AppColors.slate400),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Field 2: 10-Column Phone Number
                      _build10ColumnPhoneIndicator(_phoneController.text),
                      const SizedBox(height: 16),

                      // Field 3: Organisation Name (Required in Registration Mode)
                      if (_tabMode == 0) ...[
                        const Text('Organisation / Facility Name *', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _orgNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'e.g., Phoenix Fitness Center',
                            hintStyle: const TextStyle(color: AppColors.slate500, fontSize: 13),
                            prefixIcon: const Icon(Icons.business_rounded, color: AppColors.slate400),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Field 4: Facility Category
                        const Text('Facility Category', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                        const SizedBox(height: 16),
                      ],

                      // Field 5: OTP Code (Default 00000)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Verification OTP *', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Default OTP: 00000', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: '',
                          prefixIcon: const Icon(Icons.lock_clock_rounded, color: AppColors.slate400),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _handleTenantSubmit,
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  _tabMode == 0 ? 'Register Facility & Enter App' : 'Verify & Sign In',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Link to Onboarding Guide
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => const OnboardingScreen()),
                    );
                  },
                  child: const Text(
                    'View Setup Guide & WhatsApp Features →',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
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
