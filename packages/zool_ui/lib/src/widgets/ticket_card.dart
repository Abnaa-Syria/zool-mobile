import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme.dart';
import 'basics.dart';

/// A boarding ticket: passenger, seat, ticket number and the server-signed QR code
/// (`qrPayload`). Without a payload (cancelled / not confirmed) the QR area explains why.
class TicketQrCard extends StatelessWidget {
  const TicketQrCard({
    super.key,
    required this.ticketNumber,
    required this.passengerName,
    required this.seatLabel,
    required this.qrPayload,
    this.statusLabel,
    this.statusTone = BadgeTone.neutral,
    this.footer,
  });

  final String ticketNumber;
  final String passengerName;
  final String seatLabel;
  final String? qrPayload;
  final String? statusLabel;
  final BadgeTone statusTone;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ZoolCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(passengerName, style: t.titleSmall),
                    const SizedBox(height: 2),
                    Text('مقعد $seatLabel', style: t.bodySmall),
                  ],
                ),
              ),
              if (statusLabel != null) StatusBadge(statusLabel!, tone: statusTone),
            ],
          ),
          const SizedBox(height: 14),
          if (qrPayload != null && qrPayload!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: ZoolColors.divider), borderRadius: BorderRadius.circular(12)),
              child: QrImageView(
                data: qrPayload!,
                size: 190,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ZoolColors.text),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ZoolColors.text),
                semanticsLabel: 'رمز صعود التذكرة $ticketNumber',
              ),
            )
          else
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: ZoolColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
              child: Text('رمز الصعود غير متاح لهذه التذكرة', style: t.bodySmall),
            ),
          const SizedBox(height: 10),
          SelectableText(ticketNumber, style: t.titleSmall?.copyWith(letterSpacing: 1)),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}
