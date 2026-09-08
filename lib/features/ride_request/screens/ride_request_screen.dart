import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/core/theme.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/features/fare/fare_calculator_service.dart';
import 'package:py55/features/map/location_service.dart';
import 'package:py55/features/ride_request/ride_request_service.dart';
import 'package:py55/features/ride_request/screens/ride_searching_screen.dart';
import 'package:py55/shared/models/ride_request_model.dart';

/// Pantalla para que el pasajero fije el origen y destino en el mapa,
/// consulte la tarifa calculada y confirme la solicitud de viaje.
class RideRequestScreen extends StatefulWidget {
  final LatLng? initialOrigin;
  final LatLng? initialDestination;

  const RideRequestScreen({
    super.key,
    this.initialOrigin,
    this.initialDestination,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  final RideRequestService _rideService = RideRequestService();

  GoogleMapController? _mapController;

  LatLng? _origin;
  LatLng? _destination;
  String _originAddress = 'Cargando ubicación actual...';
  String _destinationAddress = 'Toca el mapa para elegir destino';

  FareEstimate? _fareEstimate;
  double _montoOfrecido = 0.0;
  bool _isCreatingRequest = false;

  static const LatLng _defaultLocation = LatLng(-12.046374, -77.042793);

  @override
  void initState() {
    super.initState();
    _initLocations();
  }

  Future<void> _initLocations() async {
    if (widget.initialOrigin != null) {
      _origin = widget.initialOrigin;
      _originAddress = 'Ubicación seleccionada';
    } else {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        _origin = LatLng(pos.latitude, pos.longitude);
        _originAddress = 'Tu ubicación actual';
      } else {
        _origin = _defaultLocation;
        _originAddress = 'Ubicación aproximada';
      }
    }

    if (widget.initialDestination != null) {
      _destination = widget.initialDestination;
      _destinationAddress = 'Destino seleccionado';
      _updateFareEstimate();
    }

    if (mounted) setState(() {});
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      if (_destination == null) {
        _destination = point;
        _destinationAddress = 'Destino fijado';
      } else {
        // Si ya había destino, se actualiza al nuevo punto tocado
        _destination = point;
        _destinationAddress = 'Nuevo destino fijado';
      }
      _updateFareEstimate();
    });

    _fitMapToPoints();
  }

  void _updateFareEstimate() {
    if (_origin == null || _destination == null) return;

    final estimate = FareCalculatorService.calculateFare(
      origenLat: _origin!.latitude,
      origenLng: _origin!.longitude,
      destinoLat: _destination!.latitude,
      destinoLng: _destination!.longitude,
    );

    setState(() {
      _fareEstimate = estimate;
      _montoOfrecido = estimate.tarifaSugerida;
    });
  }

  void _fitMapToPoints() {
    if (_mapController == null || _origin == null || _destination == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        _origin!.latitude < _destination!.latitude
            ? _origin!.latitude
            : _destination!.latitude,
        _origin!.longitude < _destination!.longitude
            ? _origin!.longitude
            : _destination!.longitude,
      ),
      northeast: LatLng(
        _origin!.latitude > _destination!.latitude
            ? _origin!.latitude
            : _destination!.latitude,
        _origin!.longitude > _destination!.longitude
            ? _origin!.longitude
            : _destination!.longitude,
      ),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  Future<void> _submitRideRequest() async {
    if (_origin == null || _destination == null || _fareEstimate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un punto de destino en el mapa.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userId = context.read<AuthProvider>().userModel?.id;
    if (userId == null) return;

    setState(() => _isCreatingRequest = true);

    try {
      final ride = RideRequestModel(
        id: '', // Se genera en Firestore
        pasajeroId: userId,
        origenLat: _origin!.latitude,
        origenLng: _origin!.longitude,
        origenDireccion: _originAddress,
        destinoLat: _destination!.latitude,
        destinoLng: _destination!.longitude,
        destinoDireccion: _destinationAddress,
        distanciaKm: _fareEstimate!.distanciaKm,
        tarifaMin: _fareEstimate!.tarifaMin,
        tarifaMax: _fareEstimate!.tarifaMax,
        tarifaAcordada: _montoOfrecido,
        estado: AppConstants.rideBuscando,
        fechaCreacion: DateTime.now(),
      );

      final rideId = await _rideService.createRideRequest(ride);

      if (!mounted) return;

      setState(() => _isCreatingRequest = false);

      // Reemplaza la pantalla actual con la de búsqueda de viaje
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RideSearchingScreen(rideId: rideId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al solicitar viaje: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};

    if (_origin != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: _origin!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Origen'),
        ),
      );
    }

    if (_destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destino'),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_origin == null || _destination == null) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_origin!, _destination!],
        color: AppTheme.primaryColor,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _origin ?? _defaultLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Mototaxi'),
      ),
      body: Stack(
        children: [
          // Mapa interactivo
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 15.0,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: _onMapTapped,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Header con direcciones de origen y destino
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
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.green, size: 14),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Origen: $_originAddress',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Destino: $_destinationAddress',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _destination != null
                                  ? Colors.black87
                                  : AppTheme.primaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tarjeta inferior de confirmación de tarifa cuando hay destino
          if (_fareEstimate != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Distancia: ${_fareEstimate!.distanciaKm} km',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Rango S/ ${_fareEstimate!.tarifaMin} - S/ ${_fareEstimate!.tarifaMax}',
                            style: const TextStyle(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Selector de tarifa a ofrecer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tu oferta:',
                          style: TextStyle(fontSize: 16),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: AppTheme.primaryColor,
                              onPressed: _montoOfrecido > 2.0
                                  ? () => setState(
                                      () => _montoOfrecido -= 0.5)
                                  : null,
                            ),
                            Text(
                              'S/ ${_montoOfrecido.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: AppTheme.primaryColor,
                              onPressed: () => setState(
                                  () => _montoOfrecido += 0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botón para solicitar viaje
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isCreatingRequest ? null : _submitRideRequest,
                        icon: _isCreatingRequest
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.two_wheeler_rounded),
                        label: Text(
                          _isCreatingRequest
                              ? 'Enviando solicitud...'
                              : 'Solicitar Viaje',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
