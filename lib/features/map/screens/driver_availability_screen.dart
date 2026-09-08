import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:py55/core/theme.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/features/map/location_service.dart';
import 'package:py55/features/map/map_service.dart';

/// Pantalla para el mototaxista con control de disponibilidad "Disponible / No disponible"
/// y transmisión de su ubicación GPS en tiempo real a Firebase Realtime Database.
class DriverAvailabilityScreen extends StatefulWidget {
  const DriverAvailabilityScreen({super.key});

  @override
  State<DriverAvailabilityScreen> createState() =>
      _DriverAvailabilityScreenState();
}

class _DriverAvailabilityScreenState extends State<DriverAvailabilityScreen> {
  final MapService _mapService = MapService();

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;

  bool _isAvailable = false;
  bool _isLoadingLocation = true;
  Position? _currentPosition;
  Set<Marker> _markers = {};

  // Ubicación por defecto (Lima, Perú) si aún no carga el GPS
  static const LatLng _defaultLocation = LatLng(-12.046374, -77.042793);

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (position != null) {
      _currentPosition = position;
      _updateSelfMarker(position);
    }

    setState(() => _isLoadingLocation = false);
  }

  void _updateSelfMarker(Position pos) {
    final latLng = LatLng(pos.latitude, pos.longitude);

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('driver_self'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: 'Tu Ubicación'),
        ),
      };
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(latLng, 16.0),
    );
  }

  Future<void> _toggleAvailability(bool value) async {
    final authProvider = context.read<AuthProvider>();
    final driverId = authProvider.userModel?.id;

    if (driverId == null) return;

    if (value) {
      // Activar disponibilidad
      final hasPermission = await LocationService.checkAndRequestPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se requieren permisos de ubicación para estar disponible.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() => _isAvailable = true);

      // Iniciar transmisión de GPS
      _positionSubscription = LocationService.getPositionStream().listen((pos) {
        if (!mounted) return;
        _currentPosition = pos;
        _updateSelfMarker(pos);

        _mapService.updateDriverLocation(
          driverId: driverId,
          latitude: pos.latitude,
          longitude: pos.longitude,
          heading: pos.heading,
        );
      });
    } else {
      // Desactivar disponibilidad
      await _stopLocationUpdates();
      setState(() => _isAvailable = false);
    }
  }

  Future<void> _stopLocationUpdates() async {
    final driverId = context.read<AuthProvider>().userModel?.id;
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (driverId != null) {
      await _mapService.setDriverUnavailable(driverId);
    }
  }

  Future<void> _handleLogout() async {
    await _stopLocationUpdates();
    if (mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final initialTarget = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.nombre ?? 'Mototaxista Py55'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa de Google Maps
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 15.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          if (_isLoadingLocation)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Tarjeta superior/inferior de estado de disponibilidad
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isAvailable
                            ? AppTheme.secondaryColor
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isAvailable ? 'DISPONIBLE' : 'NO DISPONIBLE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _isAvailable
                                  ? AppTheme.secondaryColor
                                  : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            _isAvailable
                                ? 'Transmitiendo ubicación GPS...'
                                : 'Activa el switch para recibir viajes.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAvailable,
                      activeColor: AppTheme.secondaryColor,
                      onChanged: _toggleAvailability,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
