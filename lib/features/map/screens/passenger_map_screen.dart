import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:py55/core/theme.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/features/map/location_service.dart';
import 'package:py55/features/map/map_service.dart';
import 'package:py55/features/map/models/driver_location_model.dart';
import 'package:py55/shared/widgets/verified_badge.dart';

/// Pantalla principal para el Pasajero con mapa interactivo en tiempo real de mototaxis cercanas.
class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final MapService _mapService = MapService();

  GoogleMapController? _mapController;
  StreamSubscription<List<DriverLocationModel>>? _driversSubscription;

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  Map<String, Marker> _driverMarkers = {};

  static const LatLng _defaultLocation = LatLng(-12.046374, -77.042793);

  @override
  void initState() {
    super.initState();
    _initPassengerLocation();
    _listenToActiveDrivers();
  }

  @override
  void dispose() {
    _driversSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initPassengerLocation() async {
    setState(() => _isLoadingLocation = true);

    final position = await LocationService.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      if (position != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
    }
  }

  void _listenToActiveDrivers() {
    _driversSubscription = _mapService.getActiveDriversStream().listen((drivers) {
      if (!mounted) return;

      final Map<String, Marker> newMarkers = {};

      for (var driver in drivers) {
        newMarkers[driver.driverId] = Marker(
          markerId: MarkerId(driver.driverId),
          position: LatLng(driver.latitude, driver.longitude),
          rotation: driver.heading,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(
            title: 'Mototaxi Py55',
            snippet: 'Toca para ver detalles',
            onTap: () => _showDriverBottomSheet(driver.driverId),
          ),
          onTap: () => _showDriverBottomSheet(driver.driverId),
        );
      }

      setState(() {
        _driverMarkers = newMarkers;
      });
    });
  }

  /// Muestra una tarjeta inferior (Bottom Sheet) con los detalles del mototaxista seleccionado.
  void _showDriverBottomSheet(String driverId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: _mapService.getDriverDetails(driverId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return const SizedBox(
                height: 180,
                child: Center(
                  child: Text('No se pudieron cargar los datos del conductor.'),
                ),
              );
            }

            final nombre = data['nombre'] as String;
            final fotoUrl = data['fotoPerfilUrl'] as String?;
            final calificacion = data['calificacion'] as double;
            final placa = data['placa'] as String;
            final vehiculo = '${data['marcaVehiculo']} ${data['modeloVehiculo']}'.trim();
            final isVerified = data['verificado'] as bool;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar superior
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Foto de Perfil o Avatar
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        backgroundImage:
                            fotoUrl != null ? NetworkImage(fotoUrl) : null,
                        child: fotoUrl == null
                            ? const Icon(Icons.two_wheeler_rounded,
                                size: 32, color: AppTheme.primaryColor)
                            : null,
                      ),
                      const SizedBox(width: 16),

                      // Detalles del Conductor
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                VerifiedBadge(
                                  verificado: isVerified,
                                  iconSize: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  calificacion.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  vehiculo,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PLACA: $placa',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Botón para solicitar viaje
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Solicitud iniciada para $nombre'),
                            backgroundColor: AppTheme.secondaryColor,
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text(
                        'Solicitar Viaje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final initialTarget = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${user?.nombre ?? 'Pasajero'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 15.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: Set<Marker>.of(_driverMarkers.values),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          if (_isLoadingLocation)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Banner superior con número de mototaxis cercanas
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
                    const Icon(
                      Icons.two_wheeler_rounded,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_driverMarkers.length} mototaxi(s) disponible(s)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const Text(
                            'Toca una mototaxi en el mapa para ver su conductor.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
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
