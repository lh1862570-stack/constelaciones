import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationProvider {
  StreamSubscription<Position>? _subscription;
  final StreamController<Position> _controller = StreamController<Position>.broadcast();

  Stream<Position> get stream => _controller.stream;

  Future<void> start() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // No lanzamos excepción, simplemente no emitimos
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      return;
    }

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      _controller.add(position);
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}


