library deep_link_router;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'package:install_referrer/install_referrer.dart';

typedef DeepLinkHandlerFn =
    Future<void> Function(BuildContext context, Uri uri);

class DeepLinkRoute {
  final bool Function(Uri uri) matcher;
  final DeepLinkHandlerFn handler;

  DeepLinkRoute({required this.matcher, required this.handler});
}

class DeepLinkRouter {
  final List<DeepLinkRoute> routes;
  final DeepLinkHandlerFn? onUnhandled;
  static const String _pendingUriKey = '__pending_deep_link_uri';
  late final AppLinks _appLinks;
  late final Stream<Uri> _uriStream;

  DeepLinkRouter({required this.routes, this.onUnhandled});

  /// Call in initState
  Future<void> initialize(BuildContext context) async {
    _appLinks = AppLinks();
    await _handleInitialUri(context);
    _listenToUriChanges(context);
    _fallbackPlatformHandling(context);
  }

  /// Call after login/register
  Future<void> completePendingNavigation(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pendingUriKey);
    if (stored != null) {
      prefs.remove(_pendingUriKey);
      final uri = Uri.tryParse(stored);
      if (uri != null) {
        await _matchAndHandle(context, uri);
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
    _uriStream.listen((uri) async {
      if (uri != null) {
        await _matchAndHandle(context, uri);
      }
    }, onError: (_) {});
  }

  Future<void> _matchAndHandle(BuildContext context, Uri uri) async {
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
      final referrer = await InstallReferrer.referrer;
      final uri = Uri.tryParse(referrer.name ?? '');
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
