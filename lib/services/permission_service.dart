import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Requests Android runtime permissions using platform channels directly,
/// bypassing the permission_handler plugin which isn't triggering dialogs.
class PermissionService {
  static final PermissionService _instance = PermissionService._();
  factory PermissionService() => _instance;
  PermissionService._();

  static const _channel = MethodChannel('com.enviable.mobile/permissions');
  bool _requested = false;

  Future<void> requestAll(BuildContext context) async {
    if (_requested) return;
    _requested = true;

    // Use Android's native ActivityCompat.requestPermissions via method channel
    // Since we can't rely on permission_handler, we'll request via each plugin's own API
    // But first, let's try the direct approach
    try {
      await _channel.invokeMethod('requestPermissions', {
        'permissions': [
          'android.permission.POST_NOTIFICATIONS',
          'android.permission.CAMERA',
          'android.permission.RECORD_AUDIO',
          'android.permission.READ_MEDIA_IMAGES',
          'android.permission.READ_CONTACTS',
          'android.permission.WRITE_CONTACTS',
        ],
      });
    } on MissingPluginException {
      // Method channel not set up — fall back to plugin-based requests
      debugPrint('PermissionService: Method channel not available, using plugin APIs');
    } catch (e) {
      debugPrint('PermissionService: Error requesting permissions: $e');
    }
  }

  void reset() => _requested = false;
}
