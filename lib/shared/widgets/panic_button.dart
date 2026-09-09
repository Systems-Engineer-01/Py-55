import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:py55/features/map/location_service.dart';
import 'package:py55/shared/models/panic_alert_model.dart';
import 'package:py55/shared/models/user_model.dart';

/// Widget de Botón de Pánico reutilizable.
/// Requiere mantener presionado durante 3 segundos para activarse.
class PanicButton extends StatefulWidget {
  final String rideId;
  final UserModel user;

  const PanicButton({
    super.key,
    required this.rideId,
    required this.user,
  });

  @override
  State<PanicButton> createState() => _PanicButtonState();
}

class _PanicButtonState extends State<PanicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSending = false;
  bool _alertSent = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_alertSent) {
        _triggerPanicAlert();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (_isSending || _alertSent) return;
    HapticFeedback.selectionClick();
    _controller.forward(from: 0.0);
  }

  void _onTapUp(TapUpDetails details) {
    if (_controller.isAnimating && !_alertSent) {
      _controller.reset();
    }
  }

  void _onTapCancel() {
    if (_controller.isAnimating && !_alertSent) {
      _controller.reset();
    }
  }

  Future<void> _triggerPanicAlert() async {
    setState(() {
      _isSending = true;
      _alertSent = true;
    });

    // 1. Vibración fuerte como confirmación local
    HapticFeedback.vibrate();

    try {
      // 2. Obtener ubicación GPS actual
      final pos = await LocationService.getCurrentPosition() ??
          Position(
            latitude: -12.046374,
            longitude: -77.042793,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );

      // 3. Crear documento en la colección de Firestore "alertas_panico"
      final docRef =
          FirebaseFirestore.instance.collection('alertas_panico').doc();

      final alert = PanicAlertModel(
        id: docRef.id,
        rideId: widget.rideId,
        userId: widget.user.id,
        rol: widget.user.rol,
        nombreUsuario: widget.user.nombre,
        telefono: widget.user.telefono,
        lat: pos.latitude,
        lng: pos.longitude,
        timestamp: DateTime.now(),
        estado: 'activa',
      );

      await docRef.set(alert.toMap());

      if (!mounted) return;

      setState(() => _isSending = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🚨 ¡ALERTA DE PÁNICO ENVIADA! El administrador ha sido notificado.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _alertSent = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar alerta de pánico: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Indicador circular de progreso (3 segundos)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: _controller.value,
                  strokeWidth: 5,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.yellowAccent),
                  backgroundColor: Colors.red.shade900.withOpacity(0.3),
                ),
              );
            },
          ),

          // Botón circular rojo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _alertSent ? Colors.green : Colors.red.shade700,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _alertSent ? Icons.check_circle : Icons.sos_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
