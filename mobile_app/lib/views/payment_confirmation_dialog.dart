import 'package:flutter/material.dart';

enum PaymentConfirmationAction { sendInvoice, sendPersonalMessage, skip }

const Color slate300 = Color(0xFFCBD5E1);
const Color slate400 = Color(0xFF94A3B8);

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Payment Recorded!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Text(
        '₹${amount.toStringAsFixed(0)} marked as PAID for $memberName ($monthYear).\n\nChoose an action:',
        style: const TextStyle(color: slate300, fontSize: 14),
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text('Send Invoice / Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(PaymentConfirmationAction.sendInvoice),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.greenAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.chat, color: Colors.greenAccent),
              label: const Text('Send Personal Message', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(PaymentConfirmationAction.sendPersonalMessage),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(PaymentConfirmationAction.skip),
              child: const Text('Skip', style: TextStyle(color: slate400)),
            ),
          ],
        ),
      ],
    );
  }

  static Future<bool?> showUnpaidWarningModal(BuildContext context, String memberName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Revert to Unpaid?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This payment for $memberName was previously marked as Paid. Are you sure you want to change its status to Unpaid?',
          style: const TextStyle(color: slate300, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: slate400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
