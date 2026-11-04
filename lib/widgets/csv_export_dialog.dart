import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/csv_export.dart';
import '../domain/session_repository.dart';

abstract interface class CsvDelivery {
  Future<String> share(String csv, Rect origin);
}

class NativeCsvDelivery implements CsvDelivery {
  @override
  Future<String> share(String csv, Rect origin) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(csv)),
            mimeType: 'text/csv',
            name: 'stride-sessions.csv',
          ),
        ],
        fileNameOverrides: ['stride-sessions.csv'],
        sharePositionOrigin: origin,
      ),
    );
    return switch (result.status) {
      ShareResultStatus.success =>
        'Share action selected. Check the destination to confirm the file was saved.',
      ShareResultStatus.dismissed =>
        'Share sheet dismissed. No destination selected.',
      ShareResultStatus.unavailable =>
        'Export handed to the platform; completion is not reported.',
    };
  }
}

Future<void> showCsvExport(
  BuildContext context,
  List<RecordedSession> sessions, {
  CsvDelivery? delivery,
}) => showDialog<void>(
  context: context,
  builder: (context) => _CsvDialog(
    csv: sessionsCsv(sessions),
    count: sessions.length,
    delivery: delivery ?? NativeCsvDelivery(),
  ),
);

class _CsvDialog extends StatefulWidget {
  const _CsvDialog({
    required this.csv,
    required this.count,
    required this.delivery,
  });
  final String csv;
  final int count;
  final CsvDelivery delivery;
  @override
  State<_CsvDialog> createState() => _CsvDialogState();
}

class _CsvDialogState extends State<_CsvDialog> {
  bool busy = false;
  String? status;
  Future<void> _run(Future<String> Function() operation) async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final message = await operation();
      if (mounted) {
        setState(() => status = message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => status = 'Export could not complete. Retry or use Copy CSV.',
        );
      }
    }
    if (mounted) {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Export CSV'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.count} saved simulated session(s). UTC timestamps, seconds, contacts/min and ADC shares. Blank fields mean unavailable. No bundled examples.',
            ),
            const SizedBox(height: 12),
            const Text(
              'CSV preview (first three records)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.csv.split('\r\n').take(4).join('\n'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cadence = contacts × 60 ÷ active seconds. Consistency uses recent intervals. Pressure shares are relative ADC counts, not force.',
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(status!),
              ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      TextButton(
        onPressed: busy
            ? null
            : () => _run(() async {
                await Clipboard.setData(ClipboardData(text: widget.csv));
                return 'CSV copied to clipboard.';
              }),
        child: const Text('Copy CSV'),
      ),
      Builder(
        builder: (context) => FilledButton(
          onPressed: busy
              ? null
              : () {
                  final box = context.findRenderObject()! as RenderBox;
                  final origin = box.localToGlobal(Offset.zero) & box.size;
                  _run(() => widget.delivery.share(widget.csv, origin));
                },
          child: const Text('Share CSV file'),
        ),
      ),
    ],
  );
}
