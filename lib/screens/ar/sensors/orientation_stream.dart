import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

class OrientationSample {
  const OrientationSample({required this.headingDegrees, required this.pitchDegrees});

  final double headingDegrees; // 0..360
  final double pitchDegrees; // approx -90..+90 (tilt up/down)
}

class DeviceOrientationController {
  DeviceOrientationController({this.alpha = 0.15})
      : assert(alpha > 0 && alpha < 1, 'alpha must be within (0,1)');

  final double alpha; // smoothing factor for exponential smoothing

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  final StreamController<OrientationSample> _controller = StreamController<OrientationSample>.broadcast();

  double? _smoothedHeading;
  double? _smoothedPitch;

  Stream<OrientationSample> get stream => _controller.stream;

  Future<void> start() async {
    _compassSub = FlutterCompass.events?.listen((CompassEvent event) {
      final double? rawHeading = event.heading;
      if (rawHeading == null) return;
      _smoothedHeading = _smoothCircularDegrees(_smoothedHeading, rawHeading, alpha);
      _emitIfReady();
    });

    _accelSub = accelerometerEventStream().listen((AccelerometerEvent e) {
      // Compute pitch from accelerometer (assuming device held in portrait)
      // pitch = rotation around X axis; using standard formula
      final double ax = e.x.toDouble();
      final double ay = e.y.toDouble();
      final double az = e.z.toDouble();
      final double pitchRad = math.atan2(-ax, math.sqrt(ay * ay + az * az));
      final double rawPitch = pitchRad * 180.0 / math.pi;
      _smoothedPitch = _smoothLinear(_smoothedPitch, rawPitch, alpha);
      _emitIfReady();
    });
  }

  void _emitIfReady() {
    final double? h = _smoothedHeading;
    final double? p = _smoothedPitch;
    if (h != null && p != null) {
      _controller.add(OrientationSample(headingDegrees: _normalizeDegrees(h), pitchDegrees: p));
    }
  }

  Future<void> stop() async {
    await _compassSub?.cancel();
    await _accelSub?.cancel();
    await _controller.close();
  }

  double _smoothLinear(double? prev, double current, double a) {
    if (prev == null) return current;
    return prev + a * (current - prev);
  }

  double _smoothCircularDegrees(double? prev, double current, double a) {
    if (prev == null) return _normalizeDegrees(current);
    double delta = _shortestDeltaDegrees(prev, current);
    final double candidate = prev + a * delta;
    return _normalizeDegrees(candidate);
  }

  double _normalizeDegrees(double d) {
    double v = d % 360.0;
    if (v < 0) v += 360.0;
    return v;
  }

  double _shortestDeltaDegrees(double from, double to) {
    double delta = _normalizeDegrees(to) - _normalizeDegrees(from);
    if (delta > 180.0) delta -= 360.0;
    if (delta < -180.0) delta += 360.0;
    return delta;
  }
}


