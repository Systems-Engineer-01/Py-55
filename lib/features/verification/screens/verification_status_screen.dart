import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/shared/widgets/verified_badge.dart';

/// Pantalla que se muestra mientras el estado de verificación es "pendiente".
///
/// El usuario ve un mensaje indicando que su documentación está en revisión.
class VerificationStatusScreen extends StatelessWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de verificación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Ícono animado ──
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 52,
                  color: Colors.orange.shade600,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Tu documentación está en revisión',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'Revisaremos tus documentos y te notificaremos cuando '
                'tu cuenta esté verificada. Este proceso puede tomar '
                'hasta 24 horas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Badge de verificación ──
              VerifiedBadge(verificado: user?.verificado ?? false),

              const SizedBox(height: 40),

              // ── Botón de refrescar estado ──
              OutlinedButton.icon(
                onPressed: () => auth.refreshUser(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Verificar estado'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
