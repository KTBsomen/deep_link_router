library deep_link_router;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:android_play_install_referrer/android_play_install_referrer.dart';

typedef DeepLinkHandlerFn =
    Future<void> Function(BuildContext context, Uri uri);

class DeepLinkRoute {
  final bool Function(Uri uri) matcher;
  final DeepLinkHandlerFn handler;

  DeepLinkRoute({required this.matcher, required this.handler});
}

class DeepLinkRouter {
  static final DeepLinkRouter instance = DeepLinkRouter._internal();

  factory DeepLinkRouter() => instance;

  DeepLinkRouter._internal();

  // Keep existing fields
  late List<DeepLinkRoute> routes;
  DeepLinkHandlerFn? onUnhandled;

  static const String _pendingUriKey = '__pending_deep_link_uri';
  late final AppLinks _appLinks;
  late final Stream<Uri> _uriStream;

  void configure({
    required List<DeepLinkRoute> routes,
    DeepLinkHandlerFn? onUnhandled,
  }) {
    this.routes = routes;
    this.onUnhandled = onUnhandled;
  }

  Future<void> initialize(BuildContext context) async {
    if (routes.isEmpty) {
      throw Exception(
        'DeepLinkRouter not configured. Call configure(...) before initialize().',
      );
    }

    _appLinks = AppLinks();
    await _handleInitialUri(context);
    _listenToUriChanges(context);
    _fallbackPlatformHandling(context);
  }

  static Future<void> completePendingNavigation(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pendingUriKey);
    if (stored != null) {
      prefs.remove(_pendingUriKey);
      final uri = Uri.tryParse(stored);
      if (uri != null) {
        await instance._matchAndHandle(context, uri);
      }
    }
  }

  Future<void> _handleInitialUri(BuildContext context) async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        await _matchAndHandle(context, uri);
      }
    } catch (_) {}
  }

  void _listenToUriChanges(BuildContext context) {
    _uriStream = _appLinks.uriLinkStream;
    _uriStream.listen((uri) {
      if (uri == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return; // Flutter 3.7+

        // Defer handling slightly to ensure context is ready
        Future.delayed(Duration(milliseconds: 100), () {
          if (context.mounted) {
            _matchAndHandle(context, uri);
          }
        });
      });
    }, onError: (_) {});
  }

  Future<void> _matchAndHandle(BuildContext context, Uri uri) async {
    if (routes.isEmpty) return;

    for (final route in routes) {
      if (route.matcher(uri)) {
        await _storePendingUri(uri);
        await route.handler(context, uri);
        return;
      }
    }

    if (onUnhandled != null) {
      await _storePendingUri(uri);
      await onUnhandled!(context, uri);
    }
  }

  Future<void> _storePendingUri(Uri uri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingUriKey, uri.toString());
  }

  Future<void> _fallbackPlatformHandling(BuildContext context) async {
    if (Platform.isAndroid) {
      await _checkInstallReferrer(context);
    } else if (Platform.isIOS) {
      await _checkClipboard(context);
    }
  }

  Future<void> _checkInstallReferrer(BuildContext context) async {
    try {
      final referrer = await AndroidPlayInstallReferrer.installReferrer;
      final uri = Uri.tryParse(referrer.installReferrer ?? '');
      print('Install Referrer: $referrer');
      if (uri != null) await _matchAndHandle(context, uri);
    } catch (_) {}
  }

  Future<void> _checkClipboard(BuildContext context) async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text ?? '';
      final uri = Uri.tryParse(text);
      if (uri != null && (text.contains('.') || text.contains('/'))) {
        await _matchAndHandle(context, uri);
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } catch (_) {}
  }
}
