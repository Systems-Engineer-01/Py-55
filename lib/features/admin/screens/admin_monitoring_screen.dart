import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/features/map/map_service.dart';
import 'package:py55/features/map/models/driver_location_model.dart';
import 'package:py55/shared/models/panic_alert_model.dart';

/// Pantalla de monitoreo en tiempo real para Administradores.
/// Muestra mapa con la ubicación en vivo de todos los mototaxistas,
/// alertas de pánico destacadas en rojo y el listado de la flota completa.
class AdminMonitoringScreen extends StatefulWidget {
  const AdminMonitoringScreen({super.key});

  @override
  State<AdminMonitoringScreen> createState() => _AdminMonitoringScreenState();
}

class _AdminMonitoringScreenState extends State<AdminMonitoringScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapService _mapService = MapService();

  late TabController _tabController;
  GoogleMapController? _mapController;

  StreamSubscription<List<DriverLocationModel>>? _driversSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _panicSubscription;

  Map<String, DriverLocationModel> _activeDrivers = {};
  List<PanicAlertModel> _activePanicAlerts = [];
  static const LatLng _defaultLocation = LatLng(-12.046374, -77.042793);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenToData();
  }

  @override
  void dispose() {
    _driversSubscription?.cancel();
    _panicSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _listenToData() {
    // 1. Escuchar conductores activos en tiempo real en RTDB (sin filtro de cercanía)
    _driversSubscription =
        _mapService.getActiveDriversStream().listen((drivers) {
      if (!mounted) return;
      final Map<String, DriverLocationModel> map = {};
      for (var d in drivers) {
        map[d.driverId] = d;
      }
      setState(() => _activeDrivers = map);
    });

    // 2. Escuchar alertas de pánico activas en tiempo real en Firestore
    _panicSubscription = _firestore
        .collection('alertas_panico')
        .where('estado', isEqualTo: 'activa')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final alerts = snapshot.docs
          .map((doc) => PanicAlertModel.fromMap(doc.data(), doc.id))
          .toList();
      setState(() => _activePanicAlerts = alerts);
    });
  }

  Future<void> _resolvePanicAlert(String alertId) async {
    try {
      await _firestore.collection('alertas_panico').doc(alertId).update({
        'estado': 'atendida',
        'fechaAtencion': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alerta de pánico marcada como ATENDIDA.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar alerta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPanicAlertDetails(PanicAlertModel alert) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(alert.lat, alert.lng), 16.0),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _firestore
              .collection(AppConstants.ridesCollection)
              .doc(alert.rideId)
              .get(),
          builder: (context, snapshot) {
            final rideData = snapshot.data?.data() ?? {};
            final origenDir =
                rideData['origenDireccion'] as String? ?? 'Desconocido';
            final destinoDir =
                rideData['destinoDireccion'] as String? ?? 'Desconocido';
            final pasajeroId = rideData['pasajeroId'] as String?;
            final conductorId = rideData['conductorId'] as String?;

            final otherUserId =
                alert.rol == AppConstants.rolPasajero ? conductorId : pasajeroId;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🚨 ALERTA DE PÁNICO ACTIVA',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            Text(
                              'Rol: ${alert.rol.toUpperCase()}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Datos del emisor
                  Text('Emisor de la Alerta:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text('• Nombre: ${alert.nombreUsuario}',
                      style: const TextStyle(fontSize: 14)),
                  Text('• Teléfono: ${alert.telefono}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Detalles del Viaje
                  Text('Detalles del Viaje (${alert.rideId}):',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text('• Origen: $origenDir',
                      style: const TextStyle(fontSize: 13)),
                  Text('• Destino: $destinoDir',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),

                  // Otra persona involucrada en el viaje
                  if (otherUserId != null)
                    FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: _firestore
                          .collection(AppConstants.usersCollection)
                          .doc(otherUserId)
                          .get(),
                      builder: (context, otherUserSnap) {
                        final otherData = otherUserSnap.data?.data() ?? {};
                        final otherName =
                            otherData['nombre'] as String? ?? 'Cargando...';
                        final otherPhone =
                            otherData['telefono'] as String? ?? '';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Contraparte del Viaje:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            Text(
                              '• Nombre: $otherName (${alert.rol == AppConstants.rolPasajero ? "Mototaxista" : "Pasajero"})',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text('• Teléfono: $otherPhone',
                                style: const TextStyle(fontSize: 13)),
                          ],
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Marcar como Atendida',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(context);
                        _resolvePanicAlert(alert.id);
                      },
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

  Set<Marker> _buildMapMarkers() {
    final Set<Marker> markers = {};

    // 1. Marcadores de conductores activos
    _activeDrivers.forEach((id, driver) {
      markers.add(
        Marker(
          markerId: MarkerId('driver_$id'),
          position: LatLng(driver.latitude, driver.longitude),
          rotation: driver.heading,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(
            title: 'Mototaxi Activa',
            snippet: 'ID: $id',
          ),
        ),
      );
    });

    // 2. Marcadores de alertas de pánico destacadas en rojo sobre los conductores
    for (var alert in _activePanicAlerts) {
      markers.add(
        Marker(
          markerId: MarkerId('panic_${alert.id}'),
          position: LatLng(alert.lat, alert.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '🚨 PÁNICO: ${alert.nombreUsuario}',
            snippet: 'Toca para atender alerta',
            onTap: () => _showPanicAlertDetails(alert),
          ),
          onTap: () => _showPanicAlertDetails(alert),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;

    if (user?.esAdmin != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Restringido')),
        body: const Center(
          child: Text(
            'No tienes permisos de administrador para ver esta pantalla.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo Admin & Flota'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.map_rounded), text: 'Mapa & Alertas'),
            Tab(icon: Icon(Icons.two_wheeler_rounded), text: 'Flota Total'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // PESTAÑA 1: Mapa en tiempo real con alertas de pánico destacadas
          Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultLocation,
                  zoom: 13.0,
                ),
                onMapCreated: (controller) => _mapController = controller,
                markers: _buildMapMarkers(),
                myLocationEnabled: true,
                zoomControlsEnabled: false,
              ),

              // Banner superior con resumen de alertas
              if (_activePanicAlerts.isNotEmpty)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Colors.red.shade900,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '¡${_activePanicAlerts.length} ALERTA(S) DE PÁNICO ACTIVA(S)!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const Text(
                                  'Toca los marcadores rojos en el mapa para revisar y atender.',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12),
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

          // PESTAÑA 2: Listado completo de mototaxistas de la flota
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection(AppConstants.driversCollection)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Text('No hay mototaxistas registrados.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final driverData = docs[index].data();
                  final driverId = docs[index].id;
                  final estadoVerificacion =
                      driverData['estadoVerificacion'] as String? ?? 'pendiente';
                  final placa =
                      driverData['placaVehiculo'] as String? ?? 'Sin placa';
                  final isOnline = _activeDrivers.containsKey(driverId);

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: _firestore
                        .collection(AppConstants.usersCollection)
                        .doc(driverId)
                        .get(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data() ?? {};
                      final nombre =
                          userData['nombre'] as String? ?? 'Conductor';
                      final telefono = userData['telefono'] as String? ?? '';

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isOnline
                                ? Colors.green.shade100
                                : Colors.grey.shade200,
                            child: Icon(
                              Icons.two_wheeler_rounded,
                              color: isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          title: Text(
                            nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Tel: $telefono | Placa: $placa'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: estadoVerificacion == 'aprobado'
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  estadoVerificacion.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: estadoVerificacion == 'aprobado'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isOnline ? '• EN LÍNEA' : '• OFFLINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isOnline ? Colors.green : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
