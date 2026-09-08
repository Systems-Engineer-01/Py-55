import 'package:flutter/material.dart';
import 'package:py55/core/theme.dart';
import 'package:py55/features/rating/rating_service.dart';

/// Pantalla de calificación que se muestra automáticamente al finalizar un viaje.
class RatingScreen extends StatefulWidget {
  final String rideId;
  final String quienCalifica;
  final String aCalificado;
  final String nombrePersonaCalificada;

  const RatingScreen({
    super.key,
    required this.rideId,
    required this.quienCalifica,
    required this.aCalificado,
    required this.nombrePersonaCalificada,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final RatingService _ratingService = RatingService();
  final TextEditingController _comentarioController = TextEditingController();

  int _estrellas = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);

    try {
      await _ratingService.submitRating(
        rideId: widget.rideId,
        quienCalifica: widget.quienCalifica,
        aCalificado: widget.aCalificado,
        estrellas: _estrellas,
        comentario: _comentarioController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por tu calificación!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar calificación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calificar Viaje'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),

            const CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor,
              child: Icon(Icons.star_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),

            Text(
              '¿Cómo fue tu experiencia con ${widget.nombrePersonaCalificada}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu opinión ayuda a mantener la seguridad y calidad del servicio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // Selector interactivo de 5 estrellas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return IconButton(
                  iconSize: 42,
                  icon: Icon(
                    starNumber <= _estrellas
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _estrellas = starNumber;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),

            // Campo de comentarios opcional
            TextFormField(
              controller: _comentarioController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Comentario opcional',
                hintText: 'Ej: Excelente servicio, muy puntual y amable.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Botón Enviar Calificación
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Enviar Calificación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
