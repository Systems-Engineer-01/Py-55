import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/core/theme.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/features/fare/fare_calculator_service.dart';
import 'package:py55/features/map/location_service.dart';
import 'package:py55/features/ride_request/ride_request_service.dart';
import 'package:py55/features/ride_request/screens/ride_tracking_screen.dart';
import 'package:py55/shared/models/ride_request_model.dart';

/// Pantalla para el mototaxista que escucha solicitudes cercanas (< 3km) en tiempo real.
class IncomingRideRequestsScreen extends StatefulWidget {
  const IncomingRideRequestsScreen({super.key});

  @override
  State<IncomingRideRequestsScreen> createState() =>
      _IncomingRideRequestsScreenState();
}

class _IncomingRideRequestsScreenState
    extends State<IncomingRideRequestsScreen> {
  final RideRequestService _rideService = RideRequestService();

  Position? _driverPosition;
  bool _isLoadingLocation = true;
  final Set<String> _ignoredRideIds = {};

  @override
  void initState() {
    super.initState();
    _fetchDriverLocation();
  }

  Future<void> _fetchDriverLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (mounted) {
      setState(() {
        _driverPosition = pos;
        _isLoadingLocation = false;
      });
    }
  }

  void _ignoreRide(String rideId) {
    setState(() {
      _ignoredRideIds.add(rideId);
    });
  }

  Future<void> _showAcceptConfirmationDialog(
      BuildContext context, RideRequestModel ride) async {
    final driverId = context.read<AuthProvider>().userModel?.id;
    if (driverId == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    double tarifaOfrecida = ride.tarifaAcordada ?? ride.tarifaMin;

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.two_wheeler_rounded,
                      color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('Confirmar Tarifa'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rango sugerido: S/ ${ride.tarifaMin.toStringAsFixed(1)} - S/ ${ride.tarifaMax.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tarifa a acordar:'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppTheme.primaryColor,
                        onPressed: tarifaOfrecida > 2.0
                            ? () => setDialogState(
                                () => tarifaOfrecida -= 0.5)
                            : null,
                      ),
                      Text(
                        'S/ ${tarifaOfrecida.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppTheme.primaryColor,
                        onPressed: () =>
                            setDialogState(() => tarifaOfrecida += 0.5),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, tarifaOfrecida),
                  child: const Text('Aceptar Viaje'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    // Ejecutar transacción atómica en Firestore para prevenir condiciones de carrera
    final success = await _rideService.acceptRideTransaction(
      rideId: ride.id,
      driverId: driverId,
      tarifaAcordada: result,
    );

    if (!mounted) return;

    if (success) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('¡Viaje aceptado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navegar a la pantalla de seguimiento del viaje
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) => RideTrackingScreen(
            rideId: ride.id,
            userRole: AppConstants.rolMototaxista,
          ),
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content:
              Text('¡Lo sentimos! Este viaje ya fue tomado por otro mototaxista.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Viaje Cercanas'),
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<RideRequestModel>>(
              stream: _rideService.streamPendingRides(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rides = snapshot.data ?? [];

                // Filtrar solicitudes a menos de 3.0 km de la posición del mototaxista
                final nearbyRides = rides.where((ride) {
                  if (_ignoredRideIds.contains(ride.id)) return false;

                  if (_driverPosition == null) return true;

                  final distToOrigin = FareCalculatorService.calculateDistanceKm(
                    lat1: _driverPosition!.latitude,
                    lon1: _driverPosition!.longitude,
                    lat2: ride.origenLat,
                    lon2: ride.origenLng,
                  );

                  return distToOrigin <= 3.0;
                }).toList();

                if (nearbyRides.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay solicitudes cercanas en este momento.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Permanece atento o busca una mejor zona de cobertura.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: nearbyRides.length,
                  itemBuilder: (context, index) {
                    final ride = nearbyRides[index];

                    double? distFromDriver;
                    if (_driverPosition != null) {
                      distFromDriver = FareCalculatorService.calculateDistanceKm(
                        lat1: _driverPosition!.latitude,
                        lon1: _driverPosition!.longitude,
                        lat2: ride.origenLat,
                        lon2: ride.origenLng,
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'S/ ${ride.tarifaAcordada?.toStringAsFixed(1) ?? "${ride.tarifaMin.toStringAsFixed(1)} - ${ride.tarifaMax.toStringAsFixed(1)}"}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (distFromDriver != null)
                                  Text(
                                    'A ${distFromDriver.toStringAsFixed(1)} km de ti',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Origen
                            Row(
                              children: [
                                const Icon(Icons.circle,
                                    color: Colors.green, size: 12),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Origen: ${ride.origenDireccion}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Destino
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Destino: ${ride.destinoDireccion}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Distancia del viaje: ${ride.distanciaKm.toStringAsFixed(1)} km',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),

                            const Divider(height: 24),

                            // Botones Aceptar / Ignorar
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey.shade700,
                                    ),
                                    onPressed: () => _ignoreRide(ride.id),
                                    child: const Text('Ignorar'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _showAcceptConfirmationDialog(
                                            context, ride),
                                    child: const Text('Aceptar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
