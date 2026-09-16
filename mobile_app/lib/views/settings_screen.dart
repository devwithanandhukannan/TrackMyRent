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
      setState(() {
        _templates = templatesData;
        _customFields = fieldsData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
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

          // 4. Subscription & Credit Store View
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
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Subscription', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('RentalBuddy Premium', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('30-Day Free Trial • 500 WhatsApp Credits Remaining', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Available App Plans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),

                _buildPlanCard('Basic Plan', '₹299 / month', '1 Month validity • Normal Plan • Buy credits separately'),
                _buildPlanCard('Plus Plan', '₹599 / month', '1 Month validity • Includes 100 Free WhatsApp Credits'),
                _buildPlanCard('Max Plan', '₹999 / 3 months', '3 Months validity • Includes 300 Free WhatsApp Credits'),

                const SizedBox(height: 24),
                const Text('Buy Extra WhatsApp Credits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                const Text('Purchased credits NEVER expire.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _buildCreditTopupCard('100 Credits', '₹99')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCreditTopupCard('500 Credits', '₹399')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCreditTopupCard('1000 Credits', '₹699')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String title, String price, String subtitle) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        trailing: Text(price, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 16)),
      ),
    );
  }

  Widget _buildCreditTopupCard(String title, String price) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(price, style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(double.infinity, 32),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Top-up $title for $price initiated')),
              );
            },
            child: const Text('Buy', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
