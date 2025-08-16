import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'data/iau_repository.dart';
import 'models/constellation.dart';
import 'sensors/orientation_stream.dart';
import 'widgets/constellation_overlay.dart';
import 'location/location_provider.dart';

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  Future<void>? _initFuture;
  List<Constellation> _constellations = const <Constellation>[];
  DeviceOrientationController? _orientationController;
  OrientationSample? _lastSample;
  final Map<String, Offset> _previousPositions = <String, Offset>{};
  LocationProvider? _locationProvider;
  double? _lastLatitude;
  double? _lastLongitude;
  Constellation? _focused;
  double _spriteScale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _orientationController?.stop();
    _locationProvider?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initFuture = _initialize(reuse: true);
      setState(() {});
    }
  }

  Future<void> _requestPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();
    if (statuses[Permission.camera] != PermissionStatus.granted) {
      throw Exception('Permiso de cámara denegado');
    }
  }

  Future<void> _initialize({bool reuse = false}) async {
    if (kIsWeb) return; // En web no inicializamos cámara aquí
    if (!(Platform.isAndroid || Platform.isIOS)) return; // Otros SO muestran placeholder

    await _requestPermissions();

    // Cargar constelaciones offline
    final List<Constellation> loaded = await IauRepository().loadConstellations();
    _constellations = loaded;

    // Iniciar orientación
    _orientationController ??= DeviceOrientationController(alpha: 0.15);
    await _orientationController!.start();
    _orientationController!.stream.listen((OrientationSample s) {
      setState(() {
        _lastSample = s;
      });
    });

    // Iniciar ubicación (opcional)
    _locationProvider ??= LocationProvider();
    await _locationProvider!.start();
    _locationProvider!.stream.listen((position) {
      setState(() {
        _lastLatitude = position.latitude;
        _lastLongitude = position.longitude;
      });
    });

    final List<CameraDescription> cameras = await availableCameras();
    final CameraDescription backCamera = cameras.firstWhere(
      (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.isNotEmpty ? cameras.first : throw Exception('No hay cámaras disponibles'),
    );

    if (!reuse) {
      await _cameraController?.dispose();
    }

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _cameraController!.initialize();
  }

  void _onTapConstellation(Constellation c) {
    // Toggle: si ya está enfocada, quitar enfoque
    if (_focused?.iauName == c.iauName) {
      setState(() {
        _focused = null;
        _spriteScale = 1.0;
      });
      return;
    }
    setState(() {
      _focused = c;
      _spriteScale = 1.8;
    });
    // Animación simple para volver a 1.2 (un poco más grande que normal) tras centrado
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() {
        _spriteScale = 1.2;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (kIsWeb || !(Platform.isAndroid || Platform.isIOS))
              const Center(
                child: Text(
                  'AR no soportado en esta plataforma',
                  style: TextStyle(color: Colors.white),
                ),
              )
            else
              FutureBuilder<void>(
                future: _initFuture,
                builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (_cameraController == null || !_cameraController!.value.isInitialized) {
                    return const Center(
                      child: Text('No se pudo inicializar la cámara', style: TextStyle(color: Colors.white)),
                    );
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_cameraController!),
                      if (_lastSample != null)
                        ConstellationOverlay(
                          constellations: _constellations,
                          headingDegrees: _lastSample!.headingDegrees,
                          pitchDegrees: _lastSample!.pitchDegrees,
                          previousPositions: _previousPositions,
                          onTapConstellation: _onTapConstellation,
                          focused: _focused,
                          scale: _spriteScale,
                        ),
                    ],
                  );
                },
              ),

            // HUD mínimo
            Positioned(
              left: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'AR – Cámara | constelaciones: ${_constellations.length}\nheading: ${_lastSample?.headingDegrees.toStringAsFixed(1) ?? '--'}°  pitch: ${_lastSample?.pitchDegrees.toStringAsFixed(1) ?? '--'}°\nlat: ${_lastLatitude?.toStringAsFixed(5) ?? '--'}  lon: ${_lastLongitude?.toStringAsFixed(5) ?? '--'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),

            // Espacio para FABs (colocados con padding para no chocar con el navbar curvo)
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'ar_focus_clear',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: () {
                setState(() {
                  _focused = null;
                  _spriteScale = 1.0;
                });
              },
              child: const Icon(Icons.center_focus_strong),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'ar_refresh',
              backgroundColor: const Color(0xFF33FFE6),
              foregroundColor: Colors.black,
              onPressed: () {
                _initFuture = _initialize(reuse: false);
                setState(() {});
              },
              child: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}


