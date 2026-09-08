import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/features/auth/auth_provider.dart';

/// Pantalla de selección de rol (pasajero o mototaxista).
///
/// Se muestra una sola vez cuando el usuario se autentica por primera vez
/// y aún no tiene un perfil en Firestore.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ── Título ──
              Text(
                '¿Cómo usarás Py55?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Elige tu rol para personalizar tu experiencia.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // ── Tarjeta Pasajero ──
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'Soy pasajero',
                subtitle: 'Solicita viajes de forma rápida y segura.',
                color: theme.colorScheme.primary,
                onTap: () =>
                    authProvider.saveUserWithRole(AppConstants.rolPasajero),
              ),

              const SizedBox(height: 20),

              // ── Tarjeta Conductor ──
              _RoleCard(
                icon: Icons.two_wheeler_rounded,
                title: 'Soy conductor',
                subtitle: 'Acepta viajes y genera ingresos.',
                color: theme.colorScheme.tertiary,
                onTap: () =>
                    authProvider.saveUserWithRole(AppConstants.rolMototaxista),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget interno: tarjeta de rol ─────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
