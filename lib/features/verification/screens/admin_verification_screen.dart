import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/features/admin/screens/admin_monitoring_screen.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/shared/models/driver_profile_model.dart';

/// Pantalla de administración para la revisión y aprobación/rechazo de documentos de mototaxistas.
class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateDriverVerificationStatus({
    required String userId,
    required bool isApproved,
  }) async {
    final estado = isApproved
        ? AppConstants.verificacionAprobado
        : AppConstants.verificacionRechazado;

    try {
      // Actualizar perfil de conductor
      await _firestore
          .collection(AppConstants.driversCollection)
          .doc(userId)
          .update({
        'estadoVerificacion': estado,
        'verificado': isApproved,
      });

      // Actualizar perfil de usuario
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'verificado': isApproved,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isApproved
                ? 'Conductor APROBADO correctamente.'
                : 'Conductor RECHAZADO.',
          ),
          backgroundColor: isApproved ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar verificación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePreview(BuildContext context, String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(title),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              Expanded(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'Error al cargar imagen',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;

    // Control de acceso para administradores
    if (user?.esAdmin != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso Restringido')),
        body: const Center(
          child: Text(
            'No tienes permisos de administrador para ver esta sección.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin: Verificación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.security_rounded),
            tooltip: 'Monitoreo en Vivo & Alertas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminMonitoringScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection(AppConstants.driversCollection)
            .where('estadoVerificacion',
                isEqualTo: AppConstants.verificacionPendiente)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_rounded,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay documentos pendientes de revisión.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos los mototaxistas han sido verificados.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final driverData = docs[index].data();
              final driverProfile = DriverProfileModel.fromMap(driverData);

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _firestore
                    .collection(AppConstants.usersCollection)
                    .doc(driverProfile.userId)
                    .get(),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data?.data() ?? {};
                  final nombre = userData['nombre'] as String? ?? 'Conductor';
                  final telefono =
                      userData['telefono'] as String? ?? 'Sin teléfono';
                  final placa = driverProfile.placaVehiculo ?? 'Sin placa';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'PENDIENTE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Teléfono: $telefono',
                              style: TextStyle(color: Colors.grey.shade700)),
                          Text('Placa Vehículo: $placa',
                              style: TextStyle(color: Colors.grey.shade700)),
                          const Divider(height: 24),

                          const Text(
                            'Documentos adjuntos (Toca para ampliar):',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 12),

                          // Galería de Miniaturas de Documentos
                          SizedBox(
                            height: 90,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                if (driverProfile.dniUrl != null)
                                  _buildDocThumbnail(
                                    context,
                                    'Foto DNI',
                                    driverProfile.dniUrl!,
                                  ),
                                if (driverProfile.licenciaUrl != null)
                                  _buildDocThumbnail(
                                    context,
                                    'Licencia',
                                    driverProfile.licenciaUrl!,
                                  ),
                                if (driverProfile.soatUrl != null)
                                  _buildDocThumbnail(
                                    context,
                                    'SOAT',
                                    driverProfile.soatUrl!,
                                  ),
                                if (driverProfile.fotoVehiculoUrl != null)
                                  _buildDocThumbnail(
                                    context,
                                    'Vehículo',
                                    driverProfile.fotoVehiculoUrl!,
                                  ),
                              ],
                            ),
                          ),

                          const Divider(height: 24),

                          // Botones de Decisión: Aprobar / Rechazar
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  onPressed: () =>
                                      _updateDriverVerificationStatus(
                                    userId: driverProfile.userId,
                                    isApproved: false,
                                  ),
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('Rechazar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  onPressed: () =>
                                      _updateDriverVerificationStatus(
                                    userId: driverProfile.userId,
                                    isApproved: true,
                                  ),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Aprobar'),
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
          );
        },
      ),
    );
  }

  Widget _buildDocThumbnail(
      BuildContext context, String label, String imageUrl) {
    return GestureDetector(
      onTap: () => _showImagePreview(context, label, imageUrl),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_rounded),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
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
