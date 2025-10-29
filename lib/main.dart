import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_app/firebase_options.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: GoogleMapsEx());
  }
}

class GoogleMapsEx extends StatefulWidget {
  const GoogleMapsEx({super.key});

  @override
  State<GoogleMapsEx> createState() => _GoogleMapsExState();
}

class _GoogleMapsExState extends State<GoogleMapsEx> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  late StreamSubscription<Position> positionStream;
  late BitmapDescriptor _customMapIcon;
  String _mapStyle = '';
  bool _isMapReady = false;
  Position? _currentPosition;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initMapResources();
  }

  Future<void> _initMapResources() async {
    final hasPermission = await _handlePermission();
    if (!hasPermission) {
      setState(() => _permissionDenied = true);
      return; // 🚫 Stop executing further
    }

    // Load map style
    _mapStyle = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/map_style.json');

    // Load custom icon
    _customMapIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/map_icon.jpg',
    );

    // Get user location
    await _getCurrentUserLocation();

    if (!mounted) return;
    setState(() => _isMapReady = true);
  }

  /// ✅ Request and check location permission
  Future<bool> _handlePermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.request();

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      openAppSettings(); // Optionally open settings
      return false;
    } else {
      return false;
    }
  }

  /// ✅ Get current user location
  Future<void> _getCurrentUserLocation() async {
    _currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      ),
    );
  }

  trackingUserLocation() async {
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );
    final controller = await _controller.future;
    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position? position) {
            controller.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: position != null
                      ? LatLng(position.latitude, position.longitude)
                      : LatLng(34.72409625497087, 36.71215604016843),
                  zoom: 12,
                ),
              ),
            );
          },
        );
  }

  Future<void> _goToHoms() async {
    final controller = await _controller.future;
    controller.moveCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: LatLng(34.72409625497087, 36.71215604016843),
          zoom: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Location permission denied.\nPlease enable it in settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    if (!_isMapReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }    

    return Scaffold(
      body: GoogleMap(
        myLocationEnabled:
            !_permissionDenied, // when enabled its show a blur point in user location, if _permissionDenied is true => there is no map
        style: _mapStyle,
        initialCameraPosition: CameraPosition(
          target: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          zoom: 14,
        ),
        onMapCreated: (controller) => _controller.complete(controller),
        markers: {
          Marker(
            markerId: const MarkerId('user_location'),
            position: LatLng(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            ),
            infoWindow: const InfoWindow(title: 'You are here'),
          ),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToHoms,
        child: const Icon(Icons.location_on),
      ),
    );
  }


}
