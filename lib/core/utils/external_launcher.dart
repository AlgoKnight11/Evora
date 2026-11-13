import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper for safely launching external device intents (Google Maps, phone dialer)
class ExternalLauncher {
  /// Opens Google Maps for turn-by-turn directions to the target coordinates.
  static Future<bool> launchDirections({
    required double latitude,
    required double longitude,
    required String destinationName,
  }) async {
    final encodedName = Uri.encodeComponent(destinationName);

    // 1. Google Maps Navigation intent
    final googleNavUri = Uri.parse('google.navigation:q=$latitude,$longitude&mode=d');

    // 2. Standard geo intent with label marker
    final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($encodedName)');

    // 3. Web URL fallback (handles both app deep-linking and browser navigation)
    final webDirectionsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
    );

    // Try Google Maps Navigation URI
    try {
      if (await canLaunchUrl(googleNavUri)) {
        final launched = await launchUrl(googleNavUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
    } catch (_) {}

    // Try standard geo: URI
    try {
      if (await canLaunchUrl(geoUri)) {
        final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      }
    } catch (_) {}

    // Fallback: Web directions link
    try {
      final launched = await launchUrl(webDirectionsUri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } catch (e) {
      debugPrint('[ExternalLauncher] Failed to launch maps: $e');
    }

    return false;
  }

  /// Opens the phone dialer with the target phone number.
  static Future<bool> launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('[ExternalLauncher] Failed to launch call: $e');
      return false;
    }
  }
}
