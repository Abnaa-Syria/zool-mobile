import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Ticket PDF (`GET /customer/tickets/:ticketNumber/pdf`) through the share sheet.
Future<void> shareTicket(BuildContext context, WidgetRef ref, Booking booking, Ticket ticket) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('جارٍ تجهيز التذكرة…'), duration: Duration(seconds: 2)));
  try {
    final bytes = await ref.read(apiProvider).ticketPdf(ticket.ticketNumber);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${ticket.ticketNumber}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    messenger.hideCurrentSnackBar();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      text: 'تذكرة ${ticket.passengerName} — ${booking.trip.origin.city} ← ${booking.trip.destination.city}، مقعد ${ticket.seatLabel}.',
    ));
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
}
