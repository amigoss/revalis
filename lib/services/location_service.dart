import 'package:geolocator/geolocator.dart';

/// Capture GPS silencieuse : la saisie ne doit JAMAIS être bloquée par le GPS.
/// Si la position est indisponible (refus, timeout, intérieur), on renvoie null
/// et le mouvement part sans position — le recoupement spatio-temporel du
/// registre s'appliquera aux pointages qui en ont une.
class LocationService {
  static Future<Position?> capture() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static String? toWkt(Position? p) =>
      p == null ? null : 'POINT(${p.longitude} ${p.latitude})';
}
