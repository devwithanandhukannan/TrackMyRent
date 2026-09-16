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
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _monthlyRentController = TextEditingController();
  final TextEditingController _dueDayController = TextEditingController(text: '5');

  bool _isLoading = false;
  List<dynamic> _plans = [];
  String? _selectedPlanId;
  String? _selectedGroupId;
  List<dynamic> _customFields = [];
  final Map<String, TextEditingController> _customControllers = {};

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
    _batchController.dispose();
    _monthlyRentController.dispose();
    _dueDayController.dispose();
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
            }
          } else if (fetchedPlans.isNotEmpty && _selectedPlanId == null) {
            _selectedPlanId = fetchedPlans.first['id'];
            _monthlyRentController.text = '${fetchedPlans.first['price']?.toInt() ?? 0}';
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
      _monthlyRentController.text = '${plan['price']?.toInt() ?? 0}';
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
        const SnackBar(content: Text('Please enter member name and phone number')),
      );
      return;
    }

    if (_selectedPlanId == null || _selectedPlanId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan is mandatory: You cannot add a member without selecting a Plan.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate and collect custom fields
    final Map<String, dynamic> customData = {};
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
              content: Text('Member added successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add member')),
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
    const backgroundColor = Color(0xFFF8FAF9);
    const primaryGreen = Color(0xFF059669);

    final displayPlans = _plans;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add member',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Card 1: Member Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Member details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Full name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. Priya Sharma',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Phone number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '+91 98765 43210',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card 2: Workout / Billing details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Workout details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Pick a saved plan and the training batch.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Plans options list
                    ...displayPlans.map((plan) {
                      final planId = plan['id'] as String;
                      final planName = plan['name'] as String;
                      final planPrice = (plan['price'] as num?)?.toInt() ?? 0;
                      final isSelected = _selectedPlanId == planId;

                      return GestureDetector(
                        onTap: () => _onPlanSelected(plan),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? primaryGreen : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4EE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 18,
                                  color: primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      '1 Month billing',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${planPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                isSelected ? 'Selected' : 'Tap to select',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? primaryGreen : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Group / Batch Selector if groups exist for this plan
                    Builder(
                      builder: (context) {
                        final selectedPlan = _plans.firstWhere(
                          (p) => p['id']?.toString() == _selectedPlanId,
                          orElse: () => null,
                        );
                        final groups = (selectedPlan != null && selectedPlan['groups'] is List)
                            ? (selectedPlan['groups'] as List)
                            : [];

                        if (groups.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 14),
                            const Text(
                              'Group / Batch',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Direct (No Group)'),
                                  selected: _selectedGroupId == null,
                                  onSelected: (_) => setState(() => _selectedGroupId = null),
                                  selectedColor: const Color(0xFFE6F4EE),
                                  labelStyle: TextStyle(
                                    color: _selectedGroupId == null ? primaryGreen : const Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                ...groups.map((g) {
                                  final gId = g['id']?.toString();
                                  final gName = g['name']?.toString() ?? 'Group';
                                  final isSel = _selectedGroupId == gId;
                                  return ChoiceChip(
                                    label: Text(gName),
                                    selected: isSel,
                                    onSelected: (_) => setState(() => _selectedGroupId = gId),
                                    selectedColor: const Color(0xFFE6F4EE),
                                    labelStyle: TextStyle(
                                      color: isSel ? primaryGreen : const Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 14),
                    const Text(
                      'Monthly rent',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _monthlyRentController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        hintText: '0',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter the monthly amount for this member.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),

                    const SizedBox(height: 14),
                    const Text(
                      'Payment due day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _dueDayController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '5',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Day of each month, from 1 to 31',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Card 3: Additional details (Custom Fields)
              if (_customFields.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
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
                          const Text(
                            'Additional details',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Custom fields',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Specific information defined by your facility',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ..._customFields.map((field) {
                        final fName = field['fieldName']?.toString() ?? '';
                        final isReq = field['isRequired'] == true;
                        final fType = field['fieldType']?.toString() ?? 'TEXT';
                        final controller = _customControllers[fName];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    fName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  if (isReq)
                                    const Text(
                                      ' *',
                                      style: TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: controller,
                                keyboardType: fType == 'NUMBER'
                                    ? TextInputType.number
                                    : (fType == 'DATE' ? TextInputType.datetime : TextInputType.text),
                                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: fType == 'DATE' ? 'YYYY-MM-DD' : 'Enter $fName',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryGreen, width: 1.5),
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
              ],

              const SizedBox(height: 24),

              // Save Member Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save member',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
