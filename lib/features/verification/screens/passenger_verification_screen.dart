import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/features/verification/verification_service.dart';

/// Pantalla de verificación para el **pasajero** (solo DNI).
class PassengerVerificationScreen extends StatefulWidget {
  const PassengerVerificationScreen({super.key});

  @override
  State<PassengerVerificationScreen> createState() =>
      _PassengerVerificationScreenState();
}

class _PassengerVerificationScreenState
    extends State<PassengerVerificationScreen> {
  final VerificationService _verificationService = VerificationService();
  final ImagePicker _picker = ImagePicker();

  File? _dniFile;
  bool _isUploading = false;
  String? _errorMessage;

  // ── Seleccionar imagen ──────────────────────────────────────────

  Future<void> _pickImage() async {
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

    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() => _dniFile = File(picked.path));
    }
  }

  // ── Subir DNI ──────────────────────────────────────────────────

  Future<void> _submitDni() async {
    if (_dniFile == null) {
      setState(() => _errorMessage = 'Selecciona una foto de tu DNI.');
      return;
    }

    final userId = context.read<AuthProvider>().firebaseUser?.uid;
    if (userId == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await _verificationService.uploadPassengerDni(
        userId: userId,
        file: _dniFile!,
      );

      // Refrescar estado en AuthProvider
      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al subir el DNI: ${e.toString()}';
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
        title: const Text('Verificación de identidad'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // ── Ícono ──
            Icon(
              Icons.badge_rounded,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),

            Text(
              'Verifica tu identidad',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sube una foto clara de tu DNI (ambas caras) para '
              'verificar tu cuenta.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // ── Área de foto ──
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _dniFile != null
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: _dniFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _dniFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_rounded,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Toca para seleccionar foto',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
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
                onPressed: _isUploading ? null : _submitDni,
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
                  _isUploading ? 'Subiendo...' : 'Enviar DNI',
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
