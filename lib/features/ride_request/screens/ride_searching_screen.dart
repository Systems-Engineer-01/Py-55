import 'package:flutter/material.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/core/theme.dart';
import 'package:py55/features/ride_request/ride_request_service.dart';
import 'package:py55/shared/models/ride_request_model.dart';

/// Pantalla de espera mientras se busca una mototaxi disponible.
/// Escucha en tiempo real el estado del documento en Firestore.
class RideSearchingScreen extends StatefulWidget {
  final String rideId;

  const RideSearchingScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<RideSearchingScreen> createState() => _RideSearchingScreenState();
}

class _RideSearchingScreenState extends State<RideSearchingScreen>
    with SingleTickerProviderStateMixin {
  final RideRequestService _rideService = RideRequestService();
  late AnimationController _pulseController;
  bool _isCanceling = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleCancel() async {
    if (_isCanceling) return;
    setState(() => _isCanceling = true);
    try {
      await _rideService.cancelRideRequest(widget.rideId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de viaje cancelada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCanceling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleCancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buscando Mototaxi'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _isCanceling ? null : _handleCancel,
              tooltip: 'Cancelar viaje',
            ),
          ],
        ),
        body: StreamBuilder<RideRequestModel?>(
          stream: _rideService.streamRideRequest(widget.rideId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final ride = snapshot.data;

            if (ride == null || ride.estado == AppConstants.rideCancelado) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('El viaje fue cancelado.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Volver al mapa'),
                    ),
                  ],
                ),
              );
            }

            if (ride.estado == AppConstants.rideAceptado) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.check_rounded,
                            size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '¡Mototaxi en Camino!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Un conductor ha aceptado tu solicitud de viaje.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Ver Viaje en Progreso'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Animación de Radar Pulsante
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulseController.value * 0.2);
                          final opacity = 1.0 - (_pulseController.value * 0.4);

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: scale * 1.5,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primaryColor
                                        .withOpacity(opacity * 0.3),
                                  ),
                                ),
                              ),
                              Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primaryColor
                                        .withOpacity(0.2),
                                  ),
                                ),
                              ),
                              const CircleAvatar(
                                radius: 40,
                                backgroundColor: AppTheme.primaryColor,
                                child: Icon(
                                  Icons.two_wheeler_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Buscando mototaxis cercanas...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notificando a los conductores disponibles de tu zona.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Tarjeta con detalles del viaje solicitado
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.my_location_rounded,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ride.origenDireccion,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ride.destinoDireccion,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Distancia: ${ride.distanciaKm.toStringAsFixed(1)} km',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              Text(
                                'Ofrecido: S/ ${ride.tarifaAcordada?.toStringAsFixed(1) ?? ride.tarifaMin.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryColor,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botón de Cancelación
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: _isCanceling ? null : _handleCancel,
                      icon: _isCanceling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : const Icon(Icons.cancel_outlined),
                      label: Text(
                        _isCanceling ? 'Cancelando...' : 'Cancelar Solicitud',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
