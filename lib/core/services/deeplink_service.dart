import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:rugged/core/navigation/app_router.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  String? _pendingPath;

  String? get pendingPath => _pendingPath;

  /// Consumes the pending path if it exists
  String? consumePendingPath() {
    final path = _pendingPath;
    _pendingPath = null;
    if (path != null) {
      debugPrint("DeepLinkService: Consuming pending path: $path");
    }
    return path;
  }

  Future<void> init() async {
    // 1. Handle initial link (when app is closed)
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _pendingPath = _normalizeUri(uri);
        debugPrint("DeepLinkService: Initial link captured: $_pendingPath");
      }
    } catch (e) {
      debugPrint("DeepLinkService: Failed to get initial link: $e");
    }

    // 2. Listen for incoming links (when app is in background/foreground)
    _appLinks.uriLinkStream.listen((uri) {
      final path = _normalizeUri(uri);
      _pendingPath = path;
      debugPrint("DeepLinkService: Incoming stream link captured: $path");
      
      // ELITE ACTIVE NAVIGATION & AUTH GUARD: 
      // 1. If it's an AUTH link (recovery, confirm, etc), ALWAYS push it.
      // 2. If it's a SHARE link, only push if authenticated.
      final bool isAuthLink = path.contains('reset-password') || 
                              path.contains('manage-email') || 
                              path.contains('otp') || 
                              path.contains('signin');

      if (isAuthLink || AuthProvider().isAuthenticated) {
        try {
          debugPrint("DeepLinkService: Authorized link. Pushing path: $path");
          appRouter.push(path);
        } catch (e) {
          debugPrint("DeepLinkService: Navigation push failed: $e");
        }
      } else {
        debugPrint("DeepLinkService: Unauthorized share link. Dismissing background link.");
        _pendingPath = null;
      }
    }, onError: (err) {
      debugPrint("DeepLinkService: Stream error: $err");
    });
  }

  String _normalizeUri(Uri uri) {
    String path = uri.path;

    // Remove /rugged/app/ or /rugged/ prefix if present
    if (path.toLowerCase().startsWith('/rugged/app')) {
      path = path.replaceFirst(RegExp('/rugged/app', caseSensitive: false), '');
    } else if (path.toLowerCase().startsWith('/rugged')) {
      path = path.replaceFirst(RegExp('/rugged', caseSensitive: false), '');
    }

    // Ensure path starts with /
    if (!path.startsWith('/')) {
      path = '/$path';
    }

    // Handle Auth/System Redirects (mapping Supabase paths to app routes)
    if (path.contains('recovery') || path.contains('reset-password')) {
      final source = uri.queryParameters['source'];
      path = (source == 'settings') ? '/settings/change-password' : '/reset-password';
    } else if (path.contains('signup')) {
      path = '/signin';
    } else if (path.contains('email_change') || path.contains('verify-secondary-email') || path.contains('confirm-email')) {
      path = '/settings/manage-email';
    } else if (path.contains('otp')) {
      path = '/otp';
    }

    // Construct Final URL with Query Parameters
    final fullPath = path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
    return fullPath;
  }
}
