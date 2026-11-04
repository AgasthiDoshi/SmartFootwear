import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/app_preferences.dart';

class EmergencyDispatchResult {
  const EmergencyDispatchResult({
    required this.success,
    required this.latitude,
    required this.longitude,
    required this.googleMapsUrl,
    required this.smsRecipients,
    required this.callRecipient,
    required this.message,
    this.errorMessage,
  });

  final bool success;
  final double? latitude;
  final double? longitude;
  final String googleMapsUrl;
  final List<String> smsRecipients;
  final String? callRecipient;
  final String message;
  final String? errorMessage;
}

class EmergencyDispatchService {
  static const String fallbackMapsUrl = 'https://maps.google.com';
  static const MethodChannel _telephonyChannel =
      MethodChannel('com.strideai.stride_ai/telephony');

  /// Request runtime permissions for SMS and phone calls
  static Future<void> requestPermissions() async {
    try {
      await _telephonyChannel.invokeMethod('requestPermissions');
    } catch (e) {
      debugPrint('Could not request telephony permissions: $e');
    }
  }

  /// Fetch current GPS position using geolocator with permission handling.
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied.');
          return await Geolocator.getLastKnownPosition();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return await Geolocator.getLastKnownPosition();
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('Geolocator error: $e. Attempting last known position.');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Automatically sends SMS in background via native telephony or falls back to SMS intent.
  static Future<bool> sendSms({
    required String phone,
    required String body,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // 1. Try native direct background SMS
    try {
      final success = await _telephonyChannel.invokeMethod<bool>(
        'sendDirectSms',
        {'phone': cleanPhone, 'message': body},
      );
      if (success == true) {
        debugPrint('Direct SMS sent successfully to $cleanPhone');
        return true;
      }
    } catch (nativeError) {
      debugPrint('Native SMS dispatch notice: $nativeError. Using fallback URL launcher.');
    }

    // 2. Fallback to url_launcher SMS intent
    final encodedBody = Uri.encodeComponent(body);
    final smsUri = Uri.parse('sms:$cleanPhone?body=$encodedBody');

    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        final altUri = Uri.parse('sms:$cleanPhone');
        return await launchUrl(altUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch SMS to $phone: $e');
      return false;
    }
  }

  /// Automatically initiates direct phone call via native telephony or falls back to dialer intent.
  static Future<bool> makeCall({required String phone}) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // 1. Try native direct automatic call
    try {
      final success = await _telephonyChannel.invokeMethod<bool>(
        'makeDirectCall',
        {'phone': cleanPhone},
      );
      if (success == true) {
        debugPrint('Direct call placed successfully to $cleanPhone');
        return true;
      }
    } catch (nativeError) {
      debugPrint('Native Call notice: $nativeError. Using fallback URL launcher.');
    }

    // 2. Fallback to url_launcher tel intent
    final callUri = Uri.parse('tel:$cleanPhone');
    try {
      return await launchUrl(callUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not initiate call to $phone: $e');
      return false;
    }
  }

  /// Full automated fall dispatch pipeline:
  /// 1. Obtains real GPS location via Geolocator
  /// 2. Generates Google Maps coordinates link
  /// 3. Sends SMS with location to all contacts (up to 3)
  /// 4. Automatically initiates a phone call to Contact #1
  static Future<EmergencyDispatchResult> executeFallDispatch({
    required List<EmergencyContact> contacts,
  }) async {
    final included = contacts.where((c) => c.included && c.valid).take(3).toList();
    if (included.isEmpty) {
      return const EmergencyDispatchResult(
        success: false,
        latitude: null,
        longitude: null,
        googleMapsUrl: fallbackMapsUrl,
        smsRecipients: [],
        callRecipient: null,
        message: 'No active emergency contacts configured. Please add emergency contacts.',
        errorMessage: 'Empty contacts',
      );
    }

    // 1. Get GPS coordinates
    final pos = await getCurrentLocation();
    final double? lat = pos?.latitude;
    final double? lng = pos?.longitude;

    final String mapsUrl = (lat != null && lng != null)
        ? 'https://maps.google.com/?q=$lat,$lng'
        : 'https://maps.google.com';

    final String alertText = (lat != null && lng != null)
        ? 'EMERGENCY ALERT: Smart Footwear detected a fall for user! Immediate assistance may be needed. Current GPS Location: $mapsUrl (Coordinates: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})'
        : 'EMERGENCY ALERT: Smart Footwear detected a fall for user! Immediate assistance may be needed.';

    final List<String> sentTo = [];

    // Ensure telephony permissions are requested
    await requestPermissions();

    // 2. Send SMS to all emergency contacts in background
    for (final contact in included) {
      await sendSms(phone: contact.phone, body: alertText);
      sentTo.add('${contact.name} (${contact.phone})');
    }

    // Allow SMS packets to send through radio before placing call
    await Future.delayed(const Duration(milliseconds: 1200));

    // 3. Initiate automatic phone call to Contact #1 (Primary)
    final primary = included.first;
    await makeCall(phone: primary.phone);

    return EmergencyDispatchResult(
      success: true,
      latitude: lat,
      longitude: lng,
      googleMapsUrl: mapsUrl,
      smsRecipients: sentTo,
      callRecipient: '${primary.name} (${primary.phone})',
      message:
          'Fall alert dispatched! GPS location forwarded to ${sentTo.length} contact(s) via SMS. Automated call initiated to Primary Contact: ${primary.name} (${primary.phone}).',
    );
  }
}
