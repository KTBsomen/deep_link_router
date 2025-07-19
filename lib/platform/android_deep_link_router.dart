import 'package:android_play_install_referrer/android_play_install_referrer.dart';

Future<Uri?> getPlatformDeepLink() async {
  try {
    final referrer = await AndroidPlayInstallReferrer.installReferrer;
    return Uri.tryParse(referrer.installReferrer ?? '');
  } catch (_) {
    return null;
  }
}
