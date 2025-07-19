library;

import 'package:deep_link_router/platform/exports.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

typedef DeepLinkHandlerFn =
    Future<bool> Function(BuildContext context, Uri uri);

class DeepLinkRoute {
  final bool Function(Uri uri) matcher;
  final DeepLinkHandlerFn handler;

  DeepLinkRoute({required this.matcher, required this.handler});
  static Map<String, dynamic> toJson(DeepLinkRoute route) {
    return {
      'matcher': route.matcher.toString(),
      'handler': route.handler.toString(),
    };
  }
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

  /// Configures the DeepLinkRouter with a list of routes and an optional unhandled route handler.
  ///
  /// This method sets up the routes to be used for deep link matching and provides
  /// a fallback handler for unmatched deep links.
  ///
  /// Parameters:
  /// - [routes]: A list of [DeepLinkRoute] that define how different URIs should be matched and handled
  /// - [onUnhandled]: An optional handler called when no matching route is found for a deep link
  void configure({
    required List<DeepLinkRoute> routes,
    DeepLinkHandlerFn? onUnhandled,
  }) {
    this.routes = routes;
    this.onUnhandled = onUnhandled;
  }

  /// Initializes the DeepLinkRouter with the configured routes and sets up deep link handling.
  ///
  /// This method:
  /// - Validates that routes have been configured
  /// - Ensures the context is mounted
  /// - Sets up the AppLinks instance
  /// - Handles any initial deep link
  /// - Starts listening for URI changes
  /// - Sets up fallback platform-specific deep link handling
  ///
  /// Throws an [Exception] if routes are not configured or the context is not mounted.
  ///
  /// Parameters:
  /// - [context]: The BuildContext used for deep link navigation and routing
  Future<void> initialize(BuildContext context) async {
    if (routes.isEmpty) {
      throw Exception(
        'DeepLinkRouter not configured. Call configure(...) before initialize().',
      );
    }
    if (!context.mounted) {
      throw Exception(
        'DeepLinkRouter cannot be initialized with an unmounted context.',
      );
    }

    _appLinks = AppLinks();
    await _handleInitialUri(context);
    _listenToUriChanges(context);
    _fallbackPlatformHandling(context);
  }

  /// Completes a pending deep link navigation that was previously interrupted.
  ///
  /// This method retrieves a stored deep link URI from shared preferences, removes it,
  /// and attempts to match and handle the URI if the context is mounted.
  ///
  /// Parameters:
  /// - [context]: The current build context used for navigation and routing
  ///
  /// This method is typically used to resume a deep link navigation that was
  /// deferred or interrupted during app initialization or context changes.
  static Future<void> completePendingNavigation(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pendingUriKey);
    if (stored != null) {
      prefs.remove(_pendingUriKey);
      final uri = Uri.tryParse(stored);
      if (uri != null && context.mounted) {
        await instance._matchAndHandle(context, uri);
      }
    }
  }

  /// Retrieves a pending deep link URI that was previously stored.
  ///
  /// This method checks if there is a stored deep link URI in shared preferences
  /// and returns it if available. The stored URI is not automatically removed.
  ///
  /// Returns:
  /// - A [Uri] if a pending deep link is stored, otherwise `null`.
  ///
  /// Typically used to check for a pending deep link without immediately clearing it.
  static Future<Uri?> getPendingDeepLink() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pendingUriKey);
    if (stored != null) {
      // prefs.remove(_pendingUriKey);
      return Uri.tryParse(stored);
    }
    return null;
  }

  Future<void> _handleInitialUri(BuildContext context) async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        //await _matchAndHandle(context, uri);
      }
    } catch (_) {}
  }

  void _listenToUriChanges(BuildContext context) {
    _uriStream = _appLinks.uriLinkStream;
    _uriStream.listen((uri) {
      print("chage found $uri");
      // if (!context.mounted) {
      //   return;
      // }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // if (!context.mounted) return; // Flutter 3.7+

        // Defer handling slightly to ensure context is ready
        Future.delayed(Duration(milliseconds: 100), () {
          _matchAndHandle(context, uri);
          if (context.mounted) {}
        });
      });
    }, onError: (_) {});
  }

  /// Matches and handles a deep link URI by attempting to route it through registered routes.
  ///
  /// This method tries to find a matching route for the given [uri] and execute its handler.
  /// If a route is found, the URI is temporarily stored as a pending deep link.
  /// If the route handler successfully processes the link, the pending URI is cleared.
  ///
  /// If no matching route is found and an [onUnhandled] callback is defined,
  /// it will be invoked with the unhandled URI.
  ///
  /// Parameters:
  /// - [context]: The current build context used for navigation and routing
  /// - [uri]: The incoming deep link URI to be processed
  ///
  /// Returns a [Future] that completes when routing is attempted
  Future<void> _matchAndHandle(BuildContext context, Uri uri) async {
    final prefs = await SharedPreferences.getInstance();
    if (routes.isEmpty) {
      return;
    }

    for (final route in routes) {
      if (route.matcher(uri)) {
        await _storePendingUri(uri);
        if (await route.handler(context, uri)) {
          prefs.remove(_pendingUriKey);
        } else {}

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
    final uri = await getPlatformDeepLink();
    if (uri != null) {
      await _matchAndHandle(context, uri);
    }
  }
}
