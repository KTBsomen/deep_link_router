export 'stub_deep_link_router.dart'
    if (dart.library.android) 'android_deep_link_router.dart'
    if (dart.library.ios) 'ios_deep_link_router.dart';
