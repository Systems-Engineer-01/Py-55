import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/core/theme.dart';
import 'package:py55/features/map/map_service.dart';
import 'package:py55/features/map/models/driver_location_model.dart';
import 'package:py55/features/ride_request/ride_request_service.dart';
import 'package:py55/shared/models/ride_request_model.dart';

/// Pantalla de seguimiento del viaje en vivo para Pasajero y Mototaxista.
/// Muestra el mapa con la ubicación en tiempo real del conductor y el indicador de estado por pasos.
class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  final String userRole; // "pasajero" | "mototaxista"

  const RideTrackingScreen({
    super.key,
    required this.rideId,
    required this.userRole,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final RideRequestService _rideService = RideRequestService();
  final MapService _mapService = MapService();

  GoogleMapController? _mapController;
  StreamSubscription<List<DriverLocationModel>>? _driverLocationSubscription;

  LatLng? _driverLiveLatLng;
  bool _isUpdatingStatus = false;

  static const LatLng _defaultLocation = LatLng(-12.046374, -77.042793);

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    super.dispose();
  }

  void _listenToDriverLiveLocation(String driverId) {
    if (_driverLocationSubscription != null) return;

    _driverLocationSubscription =
        _mapService.getActiveDriversStream().listen((activeDrivers) {
      if (!mounted) return;

      final driverLoc = activeDrivers.firstWhere(
        (d) => d.driverId == driverId,
        orElse: () => DriverLocationModel(
          driverId: driverId,
          latitude: 0,
          longitude: 0,
          timestamp: 0,
        ),
      );

      if (driverLoc.latitude != 0 && driverLoc.longitude != 0) {
        final newLatLng = LatLng(driverLoc.latitude, driverLoc.longitude);
        setState(() {
          _driverLiveLatLng = newLatLng;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newLatLng),
        );
      }
    });
  }

  Future<void> _changeRideStatus(String rideId, String newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _rideService.updateRideStatus(rideId, newStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar estado: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  int _getStepIndex(String estado) {
    switch (estado) {
      case AppConstants.rideAceptado:
        return 0;
      case AppConstants.rideEnCurso:
        return 1;
      case AppConstants.rideFinalizado:
        return 2;
      default:
        return 0;
    }
  }

  Set<Marker> _buildMarkers(RideRequestModel ride) {
    final Set<Marker> markers = {};

    // Marcador de Destino
    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(ride.destinoLat, ride.destinoLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destino: ${ride.destinoDireccion}'),
      ),
    );

    // Marcador de Origen
    markers.add(
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(ride.origenLat, ride.origenLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Origen: ${ride.origenDireccion}'),
      ),
    );

    // Marcador de la posición en vivo del mototaxista
    if (_driverLiveLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_live'),
          position: _driverLiveLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: const InfoWindow(title: 'Mototaxista en camino'),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(RideRequestModel ride) {
    final List<LatLng> points = [];

    if (_driverLiveLatLng != null) {
      points.add(_driverLiveLatLng!);
    } else {
      points.add(LatLng(ride.origenLat, ride.origenLng));
    }

    points.add(LatLng(ride.destinoLat, ride.destinoLng));

    return {
      Polyline(
        polylineId: const PolylineId('ride_route'),
        points: points,
        color: AppTheme.primaryColor,
        width: 5,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.userRole == AppConstants.rolMototaxista;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDriver ? 'Viaje en Progreso (Conductor)' : 'Seguimiento de Viaje'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<RideRequestModel?>(
        stream: _rideService.streamRideRequest(widget.rideId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final ride = snapshot.data;

          if (ride == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No se encontró el viaje.'),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          // Iniciar escucha del GPS del conductor si hay asignado
          if (ride.conductorId != null) {
            _listenToDriverLiveLocation(ride.conductorId!);
          }

          final currentStep = _getStepIndex(ride.estado);
          final initialTarget = _driverLiveLatLng ??
              LatLng(ride.origenLat, ride.origenLng);

          return Stack(
            children: [
              // Mapa de Google Maps
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialTarget.latitude != 0 ? initialTarget : _defaultLocation,
                  zoom: 15.0,
                ),
                onMapCreated: (controller) => _mapController = controller,
                markers: _buildMarkers(ride),
                polylines: _buildPolylines(ride),
                myLocationEnabled: true,
                zoomControlsEnabled: false,
              ),

              // Panel superior de Step Indicator de Estado del Viaje
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
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStepItem(
                          step: 0,
                          currentStep: currentStep,
                          label: 'Aceptado',
                          icon: Icons.check_circle_outline,
                        ),
                        _buildStepDivider(isActive: currentStep >= 1),
                        _buildStepItem(
                          step: 1,
                          currentStep: currentStep,
                          label: 'En curso',
                          icon: Icons.two_wheeler_rounded,
                        ),
                        _buildStepDivider(isActive: currentStep >= 2),
                        _buildStepItem(
                          step: 2,
                          currentStep: currentStep,
                          label: 'Finalizado',
                          icon: Icons.flag_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Panel inferior de acciones y detalles
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Información del viaje
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Distancia: ${ride.distanciaKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Destino: ${ride.destinoDireccion}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Text(
                            'S/ ${ride.tarifaAcordada?.toStringAsFixed(1) ?? ride.tarifaMin.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Transiciones de estado para Conductor
                      if (isDriver) ...[
                        if (ride.estado == AppConstants.rideAceptado)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isUpdatingStatus
                                  ? null
                                  : () => _changeRideStatus(
                                        ride.id,
                                        AppConstants.rideEnCurso,
                                      ),
                              icon: const Icon(Icons.navigation_rounded),
                              label: const Text(
                                'Iniciar Viaje',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (ride.estado == AppConstants.rideEnCurso)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                              ),
                              onPressed: _isUpdatingStatus
                                  ? null
                                  : () => _changeRideStatus(
                                        ride.id,
                                        AppConstants.rideFinalizado,
                                      ),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text(
                                'Finalizar Viaje',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],

                      // Si el viaje finalizó para cualquiera de los dos roles
                      if (ride.estado == AppConstants.rideFinalizado) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                '¡El viaje se completó exitosamente!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Volver al Inicio'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepItem({
    required int step,
    required int currentStep,
    required String label,
    required IconData icon,
  }) {
    final isDone = currentStep >= step;
    final isCurrent = currentStep == step;

    final color = isDone
        ? AppTheme.primaryColor
        : Colors.grey.shade400;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isDone ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 3,
        color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
    );
  }
}
