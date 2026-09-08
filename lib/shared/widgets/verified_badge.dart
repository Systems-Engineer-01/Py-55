import 'package:flutter/material.dart';

/// Badge reutilizable que muestra el estado de verificación del usuario.
///
/// - Si [verificado] es `true` → check azul con "Verificado".
/// - Si [verificado] es `false` → ícono gris con "Pendiente de verificación".
class VerifiedBadge extends StatelessWidget {
  final bool verificado;

  /// Tamaño del ícono. Por defecto 18.
  final double iconSize;

  /// Estilo opcional para el texto.
  final TextStyle? textStyle;

  const VerifiedBadge({
    super.key,
    required this.verificado,
    this.iconSize = 18,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (verificado) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            color: Colors.blue,
            size: iconSize,
          ),
          const SizedBox(width: 6),
          Text(
            'Verificado',
            style: textStyle ??
                TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule_rounded,
          color: Colors.grey,
          size: iconSize,
        ),
        const SizedBox(width: 6),
        Text(
          'Pendiente de verificación',
          style: textStyle ??
              const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
