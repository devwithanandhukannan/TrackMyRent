import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddMemberScreen extends StatefulWidget {
  final String? initialPlanId;
  final String? initialGroupId;

  const AddMemberScreen({super.key, this.initialPlanId, this.initialGroupId});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _monthlyRentController = TextEditingController();
  final TextEditingController _dueDayController = TextEditingController(text: '1');
  final TextEditingController _depositController = TextEditingController(text: '0');

  bool _isLoading = false;
  List<dynamic> _plans = [];
  String? _selectedPlanId;
  String? _selectedGroupId;
  List<dynamic> _customFields = [];
  final Map<String, TextEditingController> _customControllers = {};

  static const primaryGreen = Color(0xFF006948);
  static const secondaryContainer = Color(0xFF6CF8BB);
  static const onSecondaryContainer = Color(0xFF00714D);
  static const surfaceBg = Color(0xFFF7F9FB);
  static const textPrimary = Color(0xFF191C1E);
  static const textSecondary = Color(0xFF3D4A42);

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.initialPlanId;
    _selectedGroupId = widget.initialGroupId;
    _loadPlansAndFields();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _monthlyRentController.dispose();
    _dueDayController.dispose();
    _depositController.dispose();
    for (var c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPlansAndFields() async {
    try {
      final fetchedPlans = await ApiService.fetchPlans();
      final fetchedFields = await ApiService.fetchCustomFields();
      if (mounted) {
        setState(() {
          _plans = fetchedPlans;
          _customFields = fetchedFields;
          for (var f in fetchedFields) {
            final fName = f['fieldName']?.toString() ?? '';
            if (fName.isNotEmpty && !_customControllers.containsKey(fName)) {
              _customControllers[fName] = TextEditingController();
            }
          }

          if (widget.initialPlanId != null) {
            _selectedPlanId = widget.initialPlanId;
            final match = fetchedPlans.firstWhere(
              (p) => p['id']?.toString() == widget.initialPlanId,
              orElse: () => null,
            );
            if (match != null) {
              _monthlyRentController.text = '${match['price']?.toInt() ?? 0}';
              _depositController.text = '${(match['price']?.toInt() ?? 0) * 2}';
            }
          } else if (fetchedPlans.isNotEmpty && _selectedPlanId == null) {
            _selectedPlanId = fetchedPlans.first['id'];
            _monthlyRentController.text = '${fetchedPlans.first['price']?.toInt() ?? 0}';
            _depositController.text = '${(fetchedPlans.first['price']?.toInt() ?? 0) * 2}';
          }
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  void _onPlanSelected(Map<String, dynamic> plan) {
    setState(() {
      _selectedPlanId = plan['id'];
      _selectedGroupId = null; // reset group if plan changes
      final price = (plan['price'] as num?)?.toInt() ?? 0;
      _monthlyRentController.text = '$price';
      _depositController.text = '${price * 2}';
      if (plan['customDayNumber'] != null) {
        _dueDayController.text = '${plan['customDayNumber']}';
      }
    });
  }

  Future<void> _saveMember() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter resident name and phone number')),
      );
      return;
    }

    if (_selectedPlanId == null || _selectedPlanId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan is mandatory: Please select a plan for this resident.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate and collect custom fields
    final Map<String, dynamic> customData = {};
    if (_emailController.text.trim().isNotEmpty) {
      customData['Email'] = _emailController.text.trim();
    }
    for (var f in _customFields) {
      final fName = f['fieldName']?.toString() ?? '';
      final val = _customControllers[fName]?.text.trim() ?? '';
      if (f['isRequired'] == true && val.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fName is required')),
        );
        return;
      }
      if (val.isNotEmpty) {
        customData[fName] = val;
      }
    }

    setState(() => _isLoading = true);

    try {
      final monthlyRent = double.tryParse(_monthlyRentController.text.trim());
      final dueDay = int.tryParse(_dueDayController.text.trim());

      final success = await ApiService.createMember({
        'fullName': name,
        'phone': phone,
        'planId': _selectedPlanId,
        'groupId': _selectedGroupId,
        'duration': '30 Days',
        if (monthlyRent != null) 'monthlyRent': monthlyRent,
        if (dueDay != null) 'dueDayNumber': dueDay,
        if (customData.isNotEmpty) 'customFieldsData': customData,
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resident registered successfully!'),
              backgroundColor: primaryGreen,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add resident. Please check backend connection.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = _plans.firstWhere(
      (p) => p['id']?.toString() == _selectedPlanId,
      orElse: () => null,
    );
    final groups = (selectedPlan != null && selectedPlan['groups'] is List)
        ? (selectedPlan['groups'] as List)
        : [];

    return Scaffold(
      backgroundColor: surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Resident Registration',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Subtitle Banner
              const Text(
                'Enter member details and configure billing schedule',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 16),

              // ================= SECTION 1: BASIC INFORMATION =================
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
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF85F8C4).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person_outline, size: 18, color: primaryGreen),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '1. Basic Information',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: secondaryContainer,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Full Name Field
                    const Text('Full Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF6D7A72)),
                        hintText: 'e.g. Vikram Malhotra',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryGreen, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Number Field with WhatsApp sync
                    const Text('Mobile Phone Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      decoration: InputDecoration(
                        prefixIcon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🇮🇳 +91', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                              SizedBox(width: 8),
                              Text('|', style: TextStyle(color: Color(0xFFCBD5E1))),
                            ],
                          ),
                        ),
                        hintText: '98765 43210',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryGreen, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 14, color: onSecondaryContainer),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Used for automated 1-tap reminders & digital receipts',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: onSecondaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Email Address
                    const Text('Email Address (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.mail_outline, size: 20, color: Color(0xFF6D7A72)),
                        hintText: 'vikram@example.com',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFFF2F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryGreen, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ================= SECTION 2: PLAN & ROOM ALLOCATION =================
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
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bed_outlined, size: 18, color: onSecondaryContainer),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '2. Plan & Room Allocation',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Select Plan *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                    const SizedBox(height: 8),

                    if (_plans.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No plans found. Please add a plan first from Plans & Rooms screen.',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      )
                    else
                      ..._plans.map((plan) {
                        final planId = plan['id']?.toString() ?? '';
                        final planName = plan['name'] ?? 'Plan';
                        final planPrice = (plan['price'] as num?)?.toInt() ?? 0;
                        final durationDays = plan['durationDays'] ?? 30;
                        final isSelected = _selectedPlanId == planId;

                        return GestureDetector(
                          onTap: () => _onPlanSelected(plan),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryGreen.withValues(alpha: 0.05) : const Color(0xFFF2F4F6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? primaryGreen : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                      color: isSelected ? primaryGreen : const Color(0xFF6D7A72),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          planName,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary),
                                        ),
                                        Text(
                                          '$durationDays Days billing cycle',
                                          style: const TextStyle(fontSize: 11, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  '₹$planPrice',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? primaryGreen : textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    // Room & Group Assignment (if groups exist)
                    if (groups.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text('Assigned Room / Batch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Direct (No Room)'),
                            selected: _selectedGroupId == null,
                            onSelected: (_) => setState(() => _selectedGroupId = null),
                            selectedColor: secondaryContainer,
                            labelStyle: TextStyle(
                              color: _selectedGroupId == null ? onSecondaryContainer : textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          ...groups.map((g) {
                            final gId = g['id']?.toString();
                            final gName = g['name']?.toString() ?? 'Room';
                            final isSel = _selectedGroupId == gId;
                            return ChoiceChip(
                              avatar: const Icon(Icons.meeting_room_outlined, size: 14),
                              label: Text(gName),
                              selected: isSel,
                              onSelected: (_) => setState(() => _selectedGroupId = gId),
                              selectedColor: secondaryContainer,
                              labelStyle: TextStyle(
                                color: isSel ? onSecondaryContainer : textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            );
                          }),
                        ],
                      ),
                    ],

                    const SizedBox(height: 14),
                    // Monthly Rent & Due Day Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Monthly Rent (₹)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _monthlyRentController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  prefixText: '₹ ',
                                  filled: true,
                                  fillColor: const Color(0xFFF2F4F6),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryGreen, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Due Day (1-31)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _dueDayController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  hintText: '1',
                                  filled: true,
                                  fillColor: const Color(0xFFF2F4F6),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryGreen, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ================= SECTION 3: CUSTOM FIELDS =================
              if (_customFields.isNotEmpty) ...[
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
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEEF0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded, size: 18, color: primaryGreen),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '3. Additional Facility Fields',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ..._customFields.map((field) {
                        final fName = field['fieldName']?.toString() ?? '';
                        final isReq = field['isRequired'] == true;
                        final controller = _customControllers[fName];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(fName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                                  if (isReq)
                                    const Text(' *', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: controller,
                                style: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: 'Enter $fName',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                  filled: true,
                                  fillColor: const Color(0xFFF2F4F6),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryGreen, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Save Action Button (Stitch design)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Register Resident',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
