import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _templates = [];
  List<dynamic> _customFields = [];

  // Subscription & credits from Admin
  Map<String, dynamic>? _subscriptionData;
  List<dynamic> _appPlans = [];
  bool _actionLoading = false;

  // Tenant Bank & Payout details
  final _upiController = TextEditingController();
  final _accNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _accNameController = TextEditingController();
  bool _savingPayout = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettingsData();
  }

  Future<void> _loadSettingsData() async {
    setState(() => _isLoading = true);
    try {
      final templatesData = await ApiService.fetchWhatsAppTemplates();
      final fieldsData = await ApiService.fetchCustomFields();
      final subData = await ApiService.fetchSubscriptionCredits();
      final plansData = await ApiService.fetchAppPlans();
      setState(() {
        _templates = templatesData;
        _customFields = fieldsData;
        _subscriptionData = subData;
        _appPlans = plansData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribeToPlan(dynamic plan) async {
    setState(() => _actionLoading = true);
    final planId = plan['id']?.toString() ?? '';
    final planName = plan['name'] ?? 'Plan';
    final credits = plan['whatsappCredits'] ?? 0;

    final res = await ApiService.subscribeAppPlan(planId);
    if (res != null && res['success'] == true) {
      final subData = await ApiService.fetchSubscriptionCredits();
      if (mounted) {
        setState(() {
          _subscriptionData = subData;
          _actionLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully subscribed to $planName! $credits WhatsApp credits added.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res?['error'] ?? 'Failed to subscribe to plan'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _buyCredits(int count, String price) async {
    setState(() => _actionLoading = true);
    final res = await ApiService.purchaseCredits(count);
    if (res != null) {
      final subData = await ApiService.fetchSubscriptionCredits();
      if (mounted) {
        setState(() {
          _subscriptionData = subData;
          _actionLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count WhatsApp credits added to your account!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to purchase credits. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

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
          const SnackBar(
            content: Text('Payout & UPI details saved! Customer payments will route directly to your account.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save payout details'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openAddCustomFieldDialog() {
    final nameController = TextEditingController();
    String fieldType = 'text';
    bool isRequired = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Custom Field', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Field Label *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Blood Group, Aadhaar, Emergency Contact',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Field Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: fieldType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mandatory / Required?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Switch(
                    value: isRequired,
                    activeThumbColor: const Color(0xFF059669),
                    onChanged: (val) => setDialogState(() => isRequired = val),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
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
                        const SnackBar(content: Text('Custom field added!'), backgroundColor: Color(0xFF059669)),
                      );
                      _loadSettingsData();
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
        title: const Text('Delete Custom Field?'),
        content: const Text('Are you sure you want to remove this field? Existing data will be preserved in notes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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

  Future<void> _editTemplate(dynamic template) async {
    final controller = TextEditingController(text: template['messageText']);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${template['templateType']} Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available tags: {name}, {amount}, {due_date}, {month}, {plan}, {org_name}',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter template message...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save Template', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final success = await ApiService.updateWhatsAppTemplate(template['id'], result);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp template updated successfully!')),
        );
        _loadSettingsData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF059669);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Settings & Configuration', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryGreen,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: primaryGreen,
          tabs: const [
            Tab(icon: Icon(Icons.chat_bubble_outline_rounded), text: 'WhatsApp'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Custom Fields'),
            Tab(icon: Icon(Icons.account_balance_rounded), text: 'Payout & Bank'),
            Tab(icon: Icon(Icons.workspace_premium_rounded), text: 'Subscription'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. WhatsApp Templates View
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final tpl = _templates[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tpl['templateType'] ?? 'Template',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_note_rounded, color: primaryGreen),
                                  onPressed: () => _editTemplate(tpl),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tpl['messageText'] ?? '',
                                style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // 2. Custom Fields Manager View
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Custom Member Fields',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('Add Field', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _openAddCustomFieldDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create dynamic fields (e.g. Address, Blood Group, Aadhaar, Emergency Contact) that appear when adding members.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (_customFields.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.tune_rounded, size: 40, color: Color(0xFFCBD5E1)),
                        SizedBox(height: 8),
                        Text(
                          'No Custom Fields Created Yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap "Add Field" above to create your first custom field.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _customFields.length,
                      itemBuilder: (ctx, i) {
                        final f = _customFields[i];
                        final name = f['fieldName'] ?? 'Field';
                        final type = (f['fieldType'] ?? 'text').toString().toUpperCase();
                        final isReq = f['isRequired'] == true;
                        final id = f['id']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.short_text_rounded, color: primaryGreen, size: 20),
                            ),
                            title: Row(
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                const SizedBox(width: 8),
                                if (isReq)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                  ),
                              ],
                            ),
                            subtitle: Text('Type: $type', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                              tooltip: 'Delete field',
                              onPressed: () => _deleteCustomFieldItem(id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Bank & Payout Settings View (Direct Customer Payments)
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, color: primaryGreen, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Direct Customer Payouts',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Rent reminders sent on WhatsApp will automatically embed this UPI ID so customer payments credit directly to your account.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text('UPI ID (Recommended for Instant Direct Payment)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _upiController,
                  decoration: InputDecoration(
                    hintText: 'e.g. yourname@okaxis, gym@okhdfcbank',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.qr_code_rounded, color: primaryGreen),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Account Holder Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _accNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. FitZone Health Club',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.business_rounded, color: Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Bank Account Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _accNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 50100234567890',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.account_balance_rounded, color: Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Bank IFSC Code', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _ifscController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. HDFC0001234',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _savingPayout ? null : _savePayoutDetails,
                    child: _savingPayout
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Payout Details',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Subscription & Credit Store View (Dynamic from Admin)
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Plan Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
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
                            'CURRENT SUBSCRIPTION',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subscriptionData?['subscription']?['subscriptionName'] ?? 'Free trial 30 days',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xE6FFFFFF)),
                          const SizedBox(width: 6),
                          Text(
                            '${_subscriptionData?['credits']?['availableCredits'] ?? 100} WhatsApp Credits Remaining',
                            style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available App Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
                    if (_actionLoading)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Plans created and managed by Platform Admin with WhatsApp credits.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 12),

                if (_appPlans.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.layers_clear_rounded, size: 36, color: Color(0xFF94A3B8)),
                        SizedBox(height: 8),
                        Text('No Subscription Plans Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Platform Admin has not configured any plans yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  )
                else
                  ..._appPlans.map((plan) {
                    final planName = plan['name'] ?? 'Plan';
                    final num price = plan['price'] ?? 0;
                    final int months = plan['durationMonths'] ?? 1;
                    final int credits = plan['whatsappCredits'] ?? 100;
                    final String? tag = plan['tag'];
                    final String desc = plan['description'] ?? '';
                    final currentSubName = _subscriptionData?['subscription']?['subscriptionName'] ?? '';
                    final isCurrentPlan = currentSubName == planName;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrentPlan ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                          width: isCurrentPlan ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    planName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                  ),
                                  if (tag != null && tag.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0E7FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tag.toUpperCase(),
                                        style: const TextStyle(color: Color(0xFF4338CA), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                price == 0 ? '₹0' : '₹$price',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), fontSize: 18),
                              ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 6),
                                Text(
                                  '$credits WhatsApp Credits Included',
                                  style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$months Month${months > 1 ? 's' : ''} Validity',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                              if (isCurrentPlan)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF059669)),
                                  ),
                                  child: const Text('Active Plan', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12)),
                                )
                              else
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    elevation: 0,
                                  ),
                                  onPressed: _actionLoading ? null : () => _subscribeToPlan(plan),
                                  child: const Text('Activate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 24),
                const Text('Buy Extra WhatsApp Credits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                const Text('Purchased credits NEVER expire and add immediately to your facility.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _buildCreditTopupCard('100 Credits', '₹99', 100)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCreditTopupCard('500 Credits', '₹399', 500)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCreditTopupCard('1000 Credits', '₹699', 1000)),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditTopupCard(String title, String price, int creditsCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(double.infinity, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: _actionLoading ? null : () => _buyCredits(creditsCount, price),
            child: const Text('Buy', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
