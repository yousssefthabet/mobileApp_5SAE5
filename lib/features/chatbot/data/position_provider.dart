import 'package:geolocator/geolocator.dart';

/// Current position for the assistant, or null when unavailable.
///
/// With `request: false` it never shows a permission dialog: it only returns a
/// position if the user already granted access. With `request: true` (after the
/// assistant asked for it) it may prompt once.
Future<({double lat, double lng})?> geolocatorPosition({
  required bool request,
}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return (lat: position.latitude, lng: position.longitude);
  } catch (_) {
    return null;
  }
}
