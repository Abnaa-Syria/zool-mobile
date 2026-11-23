import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// «إرسال التذكرة»: downloads the ticket PDF and opens the share sheet (WhatsApp, SMS, …).
Future<void> shareTicket(BuildContext context, WidgetRef ref, Booking booking, BookingTicket ticket) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('جارٍ تجهيز التذكرة…'), duration: Duration(seconds: 2)));
  try {
    final bytes = await ref.read(apiProvider).ticketPdf(booking.id, ticket.ticketNumber);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${ticket.ticketNumber}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    messenger.hideCurrentSnackBar();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      text: 'تذكرة ${ticket.passengerName} — ${booking.origin} ← ${booking.destination}، مقعد ${ticket.seatLabel}. اعرض رمز QR عند الصعود.',
    ));
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
}

/// Shares every ticket of the booking as one PDF.
Future<void> shareBookingTickets(BuildContext context, WidgetRef ref, Booking booking) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('جارٍ تجهيز التذاكر…'), duration: Duration(seconds: 2)));
  try {
    final res = await ref.read(apiProvider).dispatchTickets(booking.id);
    final bytes = base64Decode(res['pdfBase64'] as String);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${booking.reference}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    messenger.hideCurrentSnackBar();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      text: 'تذاكر الحجز ${booking.reference} — ${booking.origin} ← ${booking.destination}.',
    ));
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
}
