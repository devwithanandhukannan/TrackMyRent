import 'package:flutter/material.dart';

enum PaymentConfirmationAction { sendInvoice, sendPersonalMessage, skip }

class PaymentConfirmationDialog extends StatelessWidget {
  final String memberName;
  final double amount;
  final String monthYear;

  const PaymentConfirmationDialog({
    super.key,
    required this.memberName,
    required this.amount,
    required this.monthYear,
  });

  static const primaryGreen = Color(0xFF006948);
  static const secondaryContainer = Color(0xFF6CF8BB);
  static const onSecondaryContainer = Color(0xFF00714D);
  static const textPrimary = Color(0xFF191C1E);
  static const textSecondary = Color(0xFF3D4A42);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = '${now.day.toString().padLeft(2, '0')} ${_monthName(now.month)} ${now.year}';
    final receiptNum = 'REC-${now.year}-${now.month.toString().padLeft(2, '0')}-${(now.millisecondsSinceEpoch % 9000 + 1000)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FB),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle & Close
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 20, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'SYNC COMPLETED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: primaryGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: textSecondary),
                      onPressed: () => Navigator.of(context).pop(PaymentConfirmationAction.skip),
                    ),
                  ],
                ),
              ),

              // Hero Check Badge & Amount (Stitch design)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: primaryGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryGreen.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment Recorded Successfully',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: secondaryContainer,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 12, color: onSecondaryContainer),
                              SizedBox(width: 4),
                              Text(
                                'PAID IN FULL',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: onSecondaryContainer),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECEEF0),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            monthYear,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recorded for $memberName',
                      style: const TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Ticket / Receipt Card (Stitch design)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('RECEIPT NUMBER', style: TextStyle(fontSize: 10, color: Color(0xFF6D7A72), fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(receiptNum, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Direct Settlement', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textSecondary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F4F6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Timestamp', style: TextStyle(fontSize: 10, color: textSecondary)),
                                        Text(formattedDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textPrimary)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F4F6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Payment Channel', style: TextStyle(fontSize: 10, color: textSecondary)),
                                        Text('Direct UPI • Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryGreen)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFECEEF0)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Settled', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textPrimary)),
                            Text('₹${amount.toStringAsFixed(0)}.00', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryGreen)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons (Stitch layout)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Send WhatsApp Invoice & Receipt',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        onPressed: () => Navigator.of(context).pop(PaymentConfirmationAction.sendInvoice),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE0E3E5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(context).pop(PaymentConfirmationAction.skip),
                        child: const Text(
                          'Done',
                          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : 'Month';
  }

  static Future<bool?> showUnpaidWarningModal(BuildContext context, String memberName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFBA1A1A), size: 24),
            SizedBox(width: 8),
            Text('Revert to Unpaid?', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Text(
          'This cycle for $memberName was previously recorded as Paid. Are you sure you want to revert it back to Unpaid?',
          style: const TextStyle(color: textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revert Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
