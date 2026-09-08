import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/features/verification/verification_service.dart';

/// Pantalla de subida de documentos para el **conductor / mototaxista**.
///
/// Requiere 4 documentos: DNI, Licencia, SOAT y Foto del vehículo.
class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  final VerificationService _verificationService = VerificationService();
  final ImagePicker _picker = ImagePicker();

  // Estado de cada documento: null = no seleccionado, File = seleccionado
  File? _dniFile;
  File? _licenciaFile;
  File? _soatFile;
  File? _fotoVehiculoFile;

  // URLs devueltas por Storage tras subir
  String? _dniUrl;
  String? _licenciaUrl;
  String? _soatUrl;
  String? _fotoVehiculoUrl;

  bool _isUploading = false;
  String? _errorMessage;

  // ── Seleccionar imagen ──────────────────────────────────────────

  Future<File?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 80,
    );

    return picked != null ? File(picked.path) : null;
  }

  // ── Subir todos los documentos ─────────────────────────────────

  Future<void> _submitDocuments() async {
    if (_dniFile == null ||
        _licenciaFile == null ||
        _soatFile == null ||
        _fotoVehiculoFile == null) {
      setState(() => _errorMessage = 'Debes subir los 4 documentos.');
      return;
    }

    final userId = context.read<AuthProvider>().firebaseUser?.uid;
    if (userId == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      _dniUrl = await _verificationService.uploadDriverDocument(
        userId: userId,
        tipoDocumento: 'dni',
        file: _dniFile!,
      );

      _licenciaUrl = await _verificationService.uploadDriverDocument(
        userId: userId,
        tipoDocumento: 'licencia',
        file: _licenciaFile!,
      );

      _soatUrl = await _verificationService.uploadDriverDocument(
        userId: userId,
        tipoDocumento: 'soat',
        file: _soatFile!,
      );

      _fotoVehiculoUrl = await _verificationService.uploadDriverDocument(
        userId: userId,
        tipoDocumento: 'foto_vehiculo',
        file: _fotoVehiculoFile!,
      );

      // Marcar como pendiente de revisión
      await _verificationService.submitDriverForVerification(userId);

      // Notificar al AuthProvider para que recargue el estado
      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al subir documentos: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación de documentos'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sube tus documentos para verificar tu perfil de conductor.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // ── 4 secciones de documentos ──
            _DocumentTile(
              title: 'DNI (ambas caras)',
              icon: Icons.badge_rounded,
              file: _dniFile,
              uploadedUrl: _dniUrl,
              onPick: () async {
                final f = await _pickImage();
                if (f != null) setState(() => _dniFile = f);
              },
            ),
            const SizedBox(height: 16),

            _DocumentTile(
              title: 'Licencia de conducir',
              icon: Icons.card_membership_rounded,
              file: _licenciaFile,
              uploadedUrl: _licenciaUrl,
              onPick: () async {
                final f = await _pickImage();
                if (f != null) setState(() => _licenciaFile = f);
              },
            ),
            const SizedBox(height: 16),

            _DocumentTile(
              title: 'SOAT vigente',
              icon: Icons.shield_rounded,
              file: _soatFile,
              uploadedUrl: _soatUrl,
              onPick: () async {
                final f = await _pickImage();
                if (f != null) setState(() => _soatFile = f);
              },
            ),
            const SizedBox(height: 16),

            _DocumentTile(
              title: 'Foto del vehículo',
              icon: Icons.two_wheeler_rounded,
              file: _fotoVehiculoFile,
              uploadedUrl: _fotoVehiculoUrl,
              onPick: () async {
                final f = await _pickImage();
                if (f != null) setState(() => _fotoVehiculoFile = f);
              },
            ),
            const SizedBox(height: 24),

            // ── Error ──
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Botón enviar ──
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isUploading ? null : _submitDocuments,
                icon: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _isUploading ? 'Subiendo...' : 'Enviar documentos',
                  style: const TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

// ── Widget interno: tile de documento ────────────────────────────

class _DocumentTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final File? file;
  final String? uploadedUrl;
  final VoidCallback onPick;

  const _DocumentTile({
    required this.title,
    required this.icon,
    required this.file,
    required this.uploadedUrl,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFile = file != null;
    final bool uploaded = uploadedUrl != null;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Ícono o preview
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: hasFile
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: hasFile
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(file!, fit: BoxFit.cover),
                      )
                    : Icon(icon, color: Colors.grey.shade500, size: 28),
              ),
              const SizedBox(width: 16),

              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      uploaded
                          ? '✅ Subido correctamente'
                          : hasFile
                              ? '📎 Foto seleccionada'
                              : 'Toca para seleccionar foto',
                      style: TextStyle(
                        fontSize: 13,
                        color: uploaded
                            ? Colors.green.shade700
                            : hasFile
                                ? Colors.orange.shade700
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              // Ícono de acción
              Icon(
                hasFile ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
                color: hasFile ? Colors.green : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
