import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../main.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final String phone;
  final String? initialName;
  final String? initialOrgName;

  const ProfileCompletionScreen({
    super.key,
    required this.phone,
    this.initialName,
    this.initialOrgName,
  });

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  String _selectedOrgType = 'GYM';

  final List<Map<String, String>> _orgTypes = [
    {'label': 'Gym & Fitness Center', 'value': 'GYM'},
    {'label': 'Hostel & PG Living', 'value': 'HOSTEL'},
    {'label': 'Tuition & Coaching Centre', 'value': 'TUITION_CENTER'},
    {'label': 'Rental Building / Property', 'value': 'RENTAL'},
    {'label': 'Academy & Sports Club', 'value': 'ACADEMY'},
  ];

  List<dynamic> _plans = [];
  String _selectedPlanId = 'plan_2_days_trial';
  bool _isLoadingPlans = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialOrgName != null && widget.initialOrgName!.isNotEmpty) {
      _orgNameController.text = widget.initialOrgName!;
    }
    _loadPlans();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _orgNameController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoadingPlans = true);
    try {
      final plans = await ApiService.fetchAppPlans();
      setState(() {
        _plans = plans;
        if (plans.isNotEmpty) {
          // Default to 2 days trial plan if present, else first package
          final trialPlan = plans.firstWhere(
            (p) => (p['name'] ?? '').toString().toLowerCase().contains('2 day') || (p['isFreeTrial'] == true),
            orElse: () => plans.first,
          );
          _selectedPlanId = trialPlan['id']?.toString() ?? plans.first['id'].toString();
        }
        _isLoadingPlans = false;
      });
    } catch (_) {
      setState(() {
        _plans = ApiService.fallbackPlans;
        _selectedPlanId = 'plan_2_days_trial';
        _isLoadingPlans = false;
      });
    }
  }

  Future<void> _handleCompleteProfile() async {
    final name = _nameController.text.trim();
    final orgName = _orgNameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Full Name.');
      return;
    }
    if (orgName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Organisation / Facility Name.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      // 1. Update Profile in backend (best effort)
      try {
        await ApiService.updateTenantProfile(
          adminName: name,
          orgName: orgName,
        );
      } catch (_) {}

      // 2. Subscribe to selected package
      final selectedPlan = _plans.firstWhere(
        (p) => p['id']?.toString() == _selectedPlanId,
        orElse: () => _plans.isNotEmpty ? _plans.first : ApiService.fallbackPlans.first,
      );

      try {
        await ApiService.subscribeAppPlan(
          _selectedPlanId,
          planName: selectedPlan['name'],
          whatsappCredits: (selectedPlan['whatsappCredits'] as num?)?.toInt() ?? 50,
        );
      } catch (_) {}

      // 3. Mark profile as complete in local session (always guaranteed)
      await ApiService.markProfileCompleted(
        userName: name,
        orgName: orgName,
        planId: _selectedPlanId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome to RentTrack, $name! ${selectedPlan['name']} is active.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Navigate to Main App and clear backstack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      // Fallback: guarantee navigation into app so user is never blocked
      await ApiService.markProfileCompleted(
        userName: name,
        orgName: orgName,
        planId: _selectedPlanId,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.iosBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profile & Setup',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Reload Packages',
            onPressed: _isLoadingPlans ? null : _loadPlans,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPlans,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              const Text(
                'Complete Your Profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Provide your details and choose your starting package to begin managing members, rent, and collections.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Verified Phone Card (Apple Style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.iosCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.iosBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.appleGreenBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.appleGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mobile Number Verified',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.phone.startsWith('+91') ? widget.phone : '+91 ${widget.phone}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.appleGreenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Verified ✓',
                        style: TextStyle(
                          color: AppColors.appleGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Basic Information Card
              const Text(
                'BASIC DETAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.iosCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.iosBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name Input
                    const Text(
                      'Your Full Name (Owner / Admin) *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Anandhu Kannan',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.primary),
                        filled: true,
                        fillColor: const Color(0xFFF8FAF9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.iosBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.iosBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Organization / Facility Name
                    const Text(
                      'Facility / Organisation Name *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _orgNameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Power Fitness Gym / Green Hostel',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        prefixIcon: const Icon(Icons.apartment_rounded, size: 20, color: AppColors.primary),
                        filled: true,
                        fillColor: const Color(0xFFF8FAF9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.iosBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.iosBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Organization Type Dropdown
                    const Text(
                      'Business Category',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedOrgType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAF9),
                        prefixIcon: const Icon(Icons.category_outlined, size: 20, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.iosBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.iosBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      items: _orgTypes.map((type) {
                        return DropdownMenuItem(
                          value: type['value'],
                          child: Text(
                            type['label']!,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedOrgType = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 2: Choose Starting Package (Apple Style Cards)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CHOOSE PACKAGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.mintBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '2 Days Trial Included',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoadingPlans)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                ..._plans.map((plan) {
                  final id = plan['id']?.toString() ?? '';
                  final isSelected = id == _selectedPlanId;
                  final isTrial = plan['isFreeTrial'] == true || (plan['name'] ?? '').toString().toLowerCase().contains('2 day');
                  final price = (plan['price'] as num?)?.toDouble() ?? 0.0;
                  final credits = plan['whatsappCredits'] ?? 50;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedPlanId = id),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF2FBF7) : AppColors.iosCardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.iosBorder,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppColors.primary : AppColors.slate400,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      plan['name'] ?? 'Plan',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (isTrial) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.appleGreenBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Free 2 Days',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.appleGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  plan['description'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$credits WhatsApp Credits included',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                price == 0 ? 'FREE' : '₹${price.toInt()}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: price == 0 ? AppColors.appleGreen : AppColors.textPrimary,
                                ),
                              ),
                              if (price > 0)
                                const Text(
                                  '/ period',
                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              // Credit Rollover Guarantee Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mintBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.mintBorder),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Credit Rollover Guarantee: Any unused WhatsApp credits remain safe and roll over automatically whenever you renew or choose a new subscription.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.appleRedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.appleRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.appleRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.appleRed, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Complete Profile Button (Apple Style)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleCompleteProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Complete Setup & Enter App',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
