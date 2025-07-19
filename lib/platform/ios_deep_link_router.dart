import 'package:flutter/services.dart';

Future<Uri?> getPlatformDeepLink() async {
  final data = await Clipboard.getData('text/plain');
  final text = data?.text ?? '';
  final uri = Uri.tryParse(text);
  if (uri != null && (text.contains('.') || text.contains('/'))) {
    await Clipboard.setData(const ClipboardData(text: ''));
    return uri;
  }
  return null;
}
