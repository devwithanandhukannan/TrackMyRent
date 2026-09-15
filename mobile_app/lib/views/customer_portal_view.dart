import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import 'login_screen.dart';

class CustomerPortalView extends StatefulWidget {
  final Map<String, dynamic> customerData;

  const CustomerPortalView({super.key, required this.customerData});

  @override
  State<CustomerPortalView> createState() => _CustomerPortalViewState();
}

class _CustomerPortalViewState extends State<CustomerPortalView> {
  bool _isProcessingPayment = false;

  void _handleLogout() async {
    await ApiService.clearSession();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (ctx) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.customerData['member'] ?? {};
    final duesSummary = widget.customerData['duesSummary'] ?? {};
    final double pendingDues = (duesSummary['totalPendingDues'] as num?)?.toDouble() ?? 0.0;
    final List unpaidSchedules = duesSummary['unpaidSchedules'] ?? [];
    final List paidSchedules = duesSummary['paidSchedules'] ?? [];
    final List frozenSchedules = duesSummary['frozenSchedules'] ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(member['organizationName'] ?? 'Customer Portal', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Profile Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (member['fullName'] ?? 'C')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member['fullName'] ?? 'Customer',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(member['phone'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${member['plan']?['name'] ?? 'General Plan'} • ${member['group']?['name'] ?? 'Direct'}',
                            style: const TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pending Dues Banner & Razorpay Pay Now Button
            if (pendingDues > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F1D1D), Color(0xFF991B1B)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text('Pending Dues Notice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₹${pendingDues.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text('Unpaid due for current period', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF991B1B),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _isProcessingPayment
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.payment_rounded),
                        label: Text(
                          _isProcessingPayment ? 'Initiating Razorpay...' : 'Pay Now via Razorpay / UPI',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isProcessingPayment
                            ? null
                            : () async {
                                if (unpaidSchedules.isNotEmpty) {
                                  final schedule = unpaidSchedules[0];
                                  setState(() => _isProcessingPayment = true);
                                  try {
                                    final orderData = await ApiService.createRazorpayOrder(
                                      schedule['id'],
                                      member['id'],
                                      (schedule['amount'] as num).toDouble(),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Razorpay Order Created! ID: ${orderData['order']?['id']}'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Payment Error: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isProcessingPayment = false);
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Dues Paid!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('No pending payments for current period.', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Payment History Section
            const Text(
              'Payment History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            if (paidSchedules.isEmpty && frozenSchedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No payment history records found.', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
              ),

            ...paidSchedules.map((s) => Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                    title: Text('Month: ${s['monthYear']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Paid Amount: ₹${s['amount']}', style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
                    trailing: const Text('🟢 Paid', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                )),

            ...frozenSchedules.map((s) => Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.ac_unit_rounded, color: Colors.cyanAccent),
                    title: Text('Month: ${s['monthYear']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Status: Medical / Vacation Leave', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                    trailing: const Text('❄️ Frozen', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
