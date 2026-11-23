import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme.dart';

/// Server-signed boarding code as a QR (the design's barcode is replaced by QR, MISSING_SCREENS §1).
class BoardingQr extends StatelessWidget {
  const BoardingQr({super.key, required this.payload, this.size = 190, this.semanticLabel});

  final String payload;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => QrImageView(
        data: payload,
        size: size,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ZoolColors.textStrong),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: ZoolColors.textStrong),
        semanticsLabel: semanticLabel ?? 'رمز الصعود',
      );
}

/// The e-ticket from the design: white ticket, side notches at a dashed tear line, the boarding
/// code below and a scalloped bottom edge. Notches are drawn in [background] (the page color).
class TicketView extends StatelessWidget {
  const TicketView({super.key, required this.top, required this.bottom, this.background = ZoolColors.background});

  /// Reference, status, timeline and the passenger / trip details.
  final Widget top;

  /// Boarding code area.
  final Widget bottom;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: top,
        ),
        SizedBox(height: 28, child: CustomPaint(painter: _TearPainter(background))),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
          child: bottom,
        ),
        SizedBox(height: 10, child: CustomPaint(painter: _ScallopPainter(background))),
      ],
    );
  }
}

class _TearPainter extends CustomPainter {
  _TearPainter(this.background);

  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, white);
    final hole = Paint()..color = background;
    final r = size.height / 2;
    canvas.drawCircle(Offset(0, r), r, hole);
    canvas.drawCircle(Offset(size.width, r), r, hole);
    final dash = Paint()
      ..color = ZoolColors.border
      ..strokeWidth = 1.2;
    for (double x = r + 8; x < size.width - r - 8; x += 9) {
      canvas.drawLine(Offset(x, r), Offset(x + 5, r), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _TearPainter old) => old.background != background;
}

class _ScallopPainter extends CustomPainter {
  _ScallopPainter(this.background);

  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final hole = Paint()..color = background;
    const r = 8.0;
    final count = (size.width / 24).floor();
    final step = size.width / count;
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(Offset(step * i + step / 2, size.height + 1), r, hole);
    }
  }

  @override
  bool shouldRepaint(covariant _ScallopPainter old) => old.background != background;
}

/// Two-column label / value pair inside the ticket («المسافر» / «محمد أحمد»).
class TicketField extends StatelessWidget {
  const TicketField(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong), maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
