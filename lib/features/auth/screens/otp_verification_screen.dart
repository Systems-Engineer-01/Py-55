import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:py55/features/auth/auth_service.dart';

/// Pantalla para ingresar el código OTP de 6 dígitos.
class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final int? resendToken;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  final AuthService _authService = AuthService();

  late String _verificationId;
  int? _resendToken;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Temporizador de reenvío ──
  Timer? _resendTimer;
  int _resendCountdown = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    _startResendTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────

  void _startResendTimer() {
    _canResend = false;
    _resendCountdown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  // ── OTP helpers ────────────────────────────────────────────────

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-verificar cuando se llenen los 6 dígitos.
    if (_otp.length == 6) {
      _verifyOtp();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  // ── Verificar OTP ──────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    final otp = _otp;
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Ingresa los 6 dígitos del código.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithOtp(
        verificationId: _verificationId,
        otp: otp,
      );
      // Login exitoso → AuthProvider detecta el cambio.
      // Volvemos a la ruta raíz para que AuthWrapper muestre la siguiente
      // pantalla (RoleSelection o Home).
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = AuthService.friendlyError(e.code);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ocurrió un error inesperado. Intenta de nuevo.';
      });
    }
  }

  // ── Reenviar código ────────────────────────────────────────────

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _authService.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      resendToken: _resendToken,
      onVerificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (_) {}
      },
      onVerificationFailed: (FirebaseAuthException error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = AuthService.friendlyError(error.code);
        });
      },
      onCodeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
        });
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código reenviado')),
        );
      },
      onCodeAutoRetrievalTimeout: (_) {},
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación'),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Ícono ──
              Icon(
                Icons.sms_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // ── Título ──
              Text(
                'Ingresa el código',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enviamos un SMS a ${widget.phoneNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // ── 6 casillas OTP ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46,
                    height: 56,
                    child: KeyboardListener(
                      focusNode: FocusNode(), // wrapper para capturar backspace
                      onKeyEvent: (event) => _onKeyEvent(i, event),
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        onChanged: (value) => _onDigitChanged(i, value),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // ── Error ──
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
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

              const SizedBox(height: 24),

              // ── Botón Verificar ──
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verificar',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Reenviar código ──
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: _isLoading ? null : _resendCode,
                        child: const Text('Reenviar código'),
                      )
                    : Text(
                        'Reenviar código en $_resendCountdown s',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
