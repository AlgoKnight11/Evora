import 'dart:io';
import 'package:flutter/services.dart';

/// Requests native OS runtime permissions on-demand for the triggered task
/// (Camera or Photo Gallery) without surfacing custom pre-prompt dialogs.
class DevicePermissionService {
  static const MethodChannel _channel = MethodChannel('com.evora.app/permissions');

  /// Triggers the Android system Camera permission prompt on first use if not already granted.
  static Future<bool> ensureCameraPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestCameraPermission');
      return granted ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  /// Triggers the Android system Photos/Storage permission prompt on first use if not already granted.
  static Future<bool> ensureGalleryPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestGalleryPermission');
      return granted ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }
}
