import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int initialTabIndex;
  const SettingsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Profile details
  final _profileNameController = TextEditingController();
  final _profileOrgNameController = TextEditingController();
  String _profilePhone = '';
  String _selectedOrgType = 'GYM';
  bool _savingProfile = false;

  // Custom fields
  List<dynamic> _customFields = [];

  // Payout details
  final _upiController = TextEditingController();
  final _accNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _accNameController = TextEditingController();
  bool _savingPayout = false;

  // Subscription & Credits
  Map<String, dynamic>? _subscriptionData;
  List<dynamic> _appPlans = [];
  List<dynamic> _creditPackages = [];
  bool _actionLoading = false;

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
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _loadSettingsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _profileNameController.dispose();
    _profileOrgNameController.dispose();
    _upiController.dispose();
    _accNumberController.dispose();
    _ifscController.dispose();
    _accNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsData() async {
    setState(() => _isLoading = true);
    try {
      final fieldsData = await ApiService.fetchCustomFields();
      final subData = await ApiService.fetchSubscriptionCredits();
      final plansData = await ApiService.fetchAppPlans();
      final creditPkgsData = await ApiService.fetchCreditPackages();
      final sessionData = await ApiService.getSessionData();

      setState(() {
        _customFields = fieldsData;
        _subscriptionData = subData;
        _appPlans = plansData;
        _creditPackages = creditPkgsData;

        if (_profileNameController.text.isEmpty && sessionData['userName'] != null) {
          _profileNameController.text = sessionData['userName']!;
        }
        if (_profileOrgNameController.text.isEmpty && sessionData['orgName'] != null) {
          _profileOrgNameController.text = sessionData['orgName']!;
        }
        _profilePhone = sessionData['phone'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  // ─── 1. Profile Actions ───────────────────────────────────────────────────

  Future<void> _saveProfileDetails() async {
    final name = _profileNameController.text.trim();
    final orgName = _profileOrgNameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner Name cannot be empty.'), backgroundColor: AppColors.appleRed),
      );
      return;
    }
    if (orgName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organisation Name cannot be empty.'), backgroundColor: AppColors.appleRed),
      );
      return;
    }

    setState(() => _savingProfile = true);
    final success = await ApiService.updateTenantProfile(
      adminName: name,
      orgName: orgName,
    );
    setState(() => _savingProfile = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile'), backgroundColor: AppColors.appleRed),
        );
      }
    }
  }

  // ─── 2. Custom Field Actions ──────────────────────────────────────────────

  void _openAddCustomFieldDialog() {
    final nameController = TextEditingController();
    String fieldType = 'text';
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Add Custom Field', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Field Label *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Blood Group, Aadhaar, Emergency Contact',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAF9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Field Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: fieldType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAF9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                ),
                items: const [
                  DropdownMenuItem(value: 'text', child: Text('Text')),
                  DropdownMenuItem(value: 'number', child: Text('Number')),
                  DropdownMenuItem(value: 'date', child: Text('Date')),
                  DropdownMenuItem(value: 'boolean', child: Text('Yes / No (Toggle)')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => fieldType = val);
                },
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mandatory / Required?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                  Switch.adaptive(
                    value: isRequired,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    onChanged: (val) => setDialogState(() => isRequired = val),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final success = await ApiService.createCustomField(
                    fieldName: name,
                    fieldType: fieldType,
                    isRequired: isRequired,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Custom field added successfully!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                      _loadSettingsData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to add custom field. Please retry.'),
                          backgroundColor: AppColors.appleRed,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Save Field', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCustomFieldItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Custom Field?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to remove this field?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.appleRed, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteCustomField(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom field removed')));
        _loadSettingsData();
      }
    }
  }

  // ─── 3. Payout Actions ────────────────────────────────────────────────────

  Future<void> _savePayoutDetails() async {
    setState(() => _savingPayout = true);
    final success = await ApiService.updateTenantPayout({
      'bankUpiId': _upiController.text.trim(),
      'bankAccountNumber': _accNumberController.text.trim(),
      'bankIfsc': _ifscController.text.trim().toUpperCase(),
      'bankAccountName': _accNameController.text.trim(),
    });
    setState(() => _savingPayout = false);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payout & UPI details saved! Direct customer payments enabled.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save payout details'), backgroundColor: AppColors.appleRed),
        );
      }
    }
  }

  // ─── 4. Subscription & Credit Actions ─────────────────────────────────────

  Future<void> _subscribeToPlan(dynamic plan) async {
    setState(() => _actionLoading = true);
    final planId = plan['id']?.toString() ?? '';
    final planName = plan['name'] ?? 'Plan';
    final credits = (plan['whatsappCredits'] as num?)?.toInt() ?? 50;

    final res = await ApiService.subscribeAppPlan(
      planId,
      planName: planName,
      whatsappCredits: credits,
    );

    if (mounted) {
      setState(() => _actionLoading = false);
      if (res != null && res['success'] == true) {
        await _loadSettingsData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscribed to $planName! $credits credits added (Unused credits rolled over).'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['error'] ?? 'Failed to subscribe'), backgroundColor: AppColors.appleRed),
        );
      }
    }
  }

  Future<void> _buyCredits(int count, String price) async {
    setState(() => _actionLoading = true);
    final res = await ApiService.purchaseCredits(count);
    if (mounted) {
      setState(() => _actionLoading = false);
      if (res != null) {
        await _loadSettingsData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count WhatsApp credits added! Total available: ${res['availableCredits'] ?? count}'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to purchase credits. Please try again.'), backgroundColor: AppColors.appleRed),
        );
      }
    }
  }

  // ─── BUILD SCREEN ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.iosBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Reload Settings',
            onPressed: _loadSettingsData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Profile'),
                Tab(text: 'Custom Fields'),
                Tab(text: 'Payout'),
                Tab(text: 'Subscription Plans'),
                Tab(text: 'Credits & Details'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Edit Profile Tab
                _buildEditProfileTab(),

                // 2. Custom Fields Tab
                _buildCustomFieldsTab(),

                // 3. Payout Tab
                _buildPayoutTab(),

                // 4. Subscription Plan Tab
                _buildSubscriptionPlanTab(),

                // 5. Credit and Subscription Details Tab
                _buildCreditAndSubscriptionDetailsTab(),
              ],
            ),
    );
  }

  // ─── TAB 1: EDIT PROFILE ──────────────────────────────────────────────────

  Widget _buildEditProfileTab() {
    return RefreshIndicator(
      onRefresh: _loadSettingsData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verified Phone Number Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.appleGreenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_rounded, color: AppColors.appleGreen, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verified Account Phone',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _profilePhone.isNotEmpty ? (_profilePhone.startsWith('+91') ? _profilePhone : '+91 $_profilePhone') : 'Verified via OTP',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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
                    child: const Text('Active ✓', style: TextStyle(color: AppColors.appleGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Profile Edit Form
            Container(
              padding: const EdgeInsets.all(18),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('EDIT PROFILE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 16),

                  const Text('Owner / Admin Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _profileNameController,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAF9),
                      prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Facility / Organisation Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _profileOrgNameController,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAF9),
                      prefixIcon: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Facility Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedOrgType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAF9),
                      prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.iosBorder)),
                    ),
                    items: _orgTypes.map((type) {
                      return DropdownMenuItem(
                        value: type['value'],
                        child: Text(type['label']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedOrgType = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _savingProfile ? null : _saveProfileDetails,
                      child: _savingProfile
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text('Save Profile Changes', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: CUSTOM FIELDS ─────────────────────────────────────────────────

  Widget _buildCustomFieldsTab() {
    return RefreshIndicator(
      onRefresh: _loadSettingsData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Custom Fields', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    SizedBox(height: 2),
                    Text('Dynamic member fields for registration', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('Add Field', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _openAddCustomFieldDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_customFields.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.iosCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.iosBorder),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.tune_rounded, size: 44, color: AppColors.slate300),
                    SizedBox(height: 12),
                    Text('No Custom Fields Added', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Tap "Add Field" to create fields like Aadhaar, Blood Group, or Locker No.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ..._customFields.map((f) {
                final name = f['fieldName'] ?? 'Field';
                final type = (f['fieldType'] ?? 'text').toString().toUpperCase();
                final isReq = f['isRequired'] == true;
                final id = f['id']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.iosCardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.iosBorder),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.mintBg, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.text_fields_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                                if (isReq) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.appleRedBg, borderRadius: BorderRadius.circular(6)),
                                    child: const Text('Required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.appleRed)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Type: $type', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 20),
                        tooltip: 'Delete field',
                        onPressed: () => _deleteCustomFieldItem(id),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ─── TAB 3: PAYOUT ────────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final orgName = _profileOrgNameController.text.isNotEmpty
        ? _profileOrgNameController.text
        : 'RentTrack';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFBA1A1A), size: 22),
            SizedBox(width: 8),
            Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF191C1E))),
          ],
        ),
        content: Text('Are you sure you want to log out of $orgName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF3D4A42))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.clearSession();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _testUpiLink() async {
    final upi = _upiController.text.trim();
    if (upi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a UPI ID first to test settlement.')),
      );
      return;
    }
    final org = _profileOrgNameController.text.trim().isNotEmpty
        ? _profileOrgNameController.text.trim()
        : 'RentTrack';
    final uri = Uri.parse('upi://pay?pa=$upi&pn=${Uri.encodeComponent(org)}&am=100&cu=INR');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('UPI Scheme ready: upi://pay?pa=$upi&pn=$org\nSupported on Android/iOS UPI apps.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  // ─── TAB 3: PAYOUT (Matching Stitch settings_payout.html) ───────────────────

  Widget _buildPayoutTab() {
    final orgName = _profileOrgNameController.text.isNotEmpty
        ? _profileOrgNameController.text
        : 'Facility';

    return RefreshIndicator(
      onRefresh: _loadSettingsData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Highlight Card: 0% Commission Direct UPI Settlement (Stitch design)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    Colors.white,
                    AppColors.secondaryContainer.withValues(alpha: 0.25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '100% Direct UPI Settlement',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryContainer,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: const Text(
                                    'Zero Fee',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.onSecondaryContainer),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Payments made by members through automated WhatsApp reminder links go directly into your linked UPI account. RentTrack takes 0% commission.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Instant Peer-to-Peer Routing',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const Text(
                        'Standard NPCI UPI 2.0',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Direct UPI VPA Configuration Form (Stitch design)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Business / Landlord UPI ID (VPA) *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 12, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _upiController,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. yourname@okhdfcbank, business@upi',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF2F4F6),
                      prefixIcon: const Icon(Icons.qr_code_rounded, color: AppColors.primary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Live Test Payment Simulation Box (Stitch design)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Test Payment Simulation',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            Text(
                              'Sample: ₹100',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Verify your mobile banking app recognizes this Virtual Payment Address properly prior to automated tenant dispatch.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.launch_rounded, size: 16, color: Colors.white),
                            label: const Text('Generate Sample UPI Link', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            onPressed: _testUpiLink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Settlement Bank Account Card (Stitch design)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Settlement Bank Account',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Account Entity / Holder Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _accNameController,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. Sunrise Living Spaces LLP',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF2F4F6),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text('Bank Account Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _accNumberController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. 50100234567890',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF2F4F6),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Text('Bank IFSC Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _ifscController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g. HDFC0001234',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF2F4F6),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _savingPayout ? null : _savePayoutDetails,
                      child: _savingPayout
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text('Save Payout Details', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Logout Option with Subtle Destructive Tone (Stitch settings_payout.html)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBA1A1A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Log Out of $orgName',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      onPressed: _handleLogout,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'RentTrack Platform • End-to-End Encrypted',
                    style: TextStyle(fontSize: 10, color: Color(0xFF6D7A72)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─── TAB 4: SUBSCRIPTION PLANS ────────────────────────────────────────────

  Widget _buildSubscriptionPlanTab() {
    final currentSubName = _subscriptionData?['subscription']?['subscriptionName'] ?? '';

    return RefreshIndicator(
      onRefresh: _loadSettingsData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subscription Plans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            const Text(
              'Select or upgrade your facility plan. Unused credits roll over automatically!',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            if (_appPlans.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No plans available')))
            else
              ..._appPlans.map((plan) {
                final planName = plan['name'] ?? 'Plan';
                final num price = plan['price'] ?? 0;
                final int credits = (plan['whatsappCredits'] as num?)?.toInt() ?? 50;
                final String? tag = plan['tag'];
                final String desc = plan['description'] ?? '';
                final isCurrentPlan = currentSubName == planName;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCurrentPlan ? const Color(0xFFF2FBF7) : AppColors.iosCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentPlan ? AppColors.primary : AppColors.iosBorder,
                      width: isCurrentPlan ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isCurrentPlan ? AppColors.primary.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(planName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary)),
                              if (tag != null && tag.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.appleGreenBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(tag, style: const TextStyle(color: AppColors.appleGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            price == 0 ? 'FREE' : '₹${price.toInt()}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: price == 0 ? AppColors.appleGreen : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.mintBg, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('$credits Credits Included', style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          if (isCurrentPlan)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                              child: const Text('Current Plan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              ),
                              onPressed: _actionLoading ? null : () => _subscribeToPlan(plan),
                              child: const Text('Subscribe', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ─── TAB 5: CREDITS & SUBSCRIPTION DETAILS ────────────────────────────────

  Widget _buildCreditAndSubscriptionDetailsTab() {
    final sub = _subscriptionData?['subscription'] ?? {};
    final credits = _subscriptionData?['credits'] ?? {};
    final planName = sub['subscriptionName'] ?? '2 Days Free Trial';
    final isExpired = sub['isExpired'] == true;
    final daysRemaining = sub['daysRemaining'] ?? 0;
    final available = credits['availableCredits'] ?? 0;
    final purchased = credits['purchasedCredits'] ?? 0;
    final used = credits['usedCredits'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadSettingsData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Subscription Status Card (Apple Card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isExpired ? AppColors.appleRedBg : AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isExpired ? AppColors.appleRed : AppColors.primary).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ACTIVE SUBSCRIPTION',
                        style: TextStyle(
                          color: isExpired ? AppColors.appleRed : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isExpired ? AppColors.appleRed : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isExpired ? 'EXPIRED (View-Only)' : 'ACTIVE',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    planName,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isExpired
                        ? 'Subscription expired. App is in View-Only mode.'
                        : '$daysRemaining days remaining on this plan',
                    style: TextStyle(
                      color: isExpired ? AppColors.appleRed : Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // WhatsApp Credits Breakdown Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.iosCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.iosBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('WHATSAPP CREDITS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.8)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.mintBg, borderRadius: BorderRadius.circular(6)),
                        child: const Text('Rollover Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Available Credits', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              '$available',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: AppColors.iosBorder),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Purchased', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              '$purchased',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Used Credits', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              '$used',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Rollover explanation note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.mintBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.mintBorder),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.cached_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Unused credit rollover: Whenever you add a new subscription, unused credits are never lost and automatically add to your new balance.',
                            style: TextStyle(fontSize: 12, color: AppColors.primaryDark, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Top-Up WhatsApp Credits Store
            const Text(
              'Top-Up WhatsApp Credits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            const Text(
              'Instantly add credits for payment receipts & fee reminder messages.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            if (_creditPackages.isNotEmpty) ...[
              for (int i = 0; i < _creditPackages.length; i += 2) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildCreditTopupCard(_creditPackages[i]),
                    ),
                    const SizedBox(width: 10),
                    if (i + 1 < _creditPackages.length)
                      Expanded(
                        child: _buildCreditTopupCard(_creditPackages[i + 1]),
                      )
                    else
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildCreditTopupPill('100 Credits', '₹99', 100)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildCreditTopupPill('250 Credits', '₹199', 250)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildCreditTopupPill('500 Credits', '₹349', 500)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildCreditTopupPill('1000 Credits', '₹599', 1000)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreditTopupCard(dynamic pkg) {
    final title = pkg['name']?.toString() ?? '${pkg['credits']} Credits';
    final price = '₹${pkg['price']}';
    final count = (pkg['credits'] is int)
        ? pkg['credits'] as int
        : int.tryParse(pkg['credits'].toString()) ?? 100;
    final tag = pkg['tag']?.toString();
    final desc = pkg['description']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.iosCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.iosBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tag != null && tag.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Text(
                tag.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7E22CE),
                ),
              ),
            ),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              desc,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            price,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
              onPressed: _actionLoading ? null : () => _buyCredits(count, price),
              child: const Text(
                'Add Credits',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditTopupPill(String title, String price, int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.iosCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.iosBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primary)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
              onPressed: _actionLoading ? null : () => _buyCredits(count, price),
              child: const Text('Add Credits', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
