import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/features/auth/auth_service.dart';
import 'package:py55/features/auth/screens/otp_verification_screen.dart';

/// Pantalla para ingresar el número de teléfono y solicitar un OTP.
class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final _authService = AuthService();

  String _selectedCountryCode = '+51'; // Perú por defecto
  bool _isLoading = false;
  String? _errorMessage;

  // Códigos de país disponibles
  static const List<_CountryCode> _countryCodes = [
    _CountryCode(code: '+51', name: 'PE', flag: '🇵🇪'),
    _CountryCode(code: '+52', name: 'MX', flag: '🇲🇽'),
    _CountryCode(code: '+54', name: 'AR', flag: '🇦🇷'),
    _CountryCode(code: '+56', name: 'CL', flag: '🇨🇱'),
    _CountryCode(code: '+57', name: 'CO', flag: '🇨🇴'),
    _CountryCode(code: '+58', name: 'VE', flag: '🇻🇪'),
    _CountryCode(code: '+55', name: 'BR', flag: '🇧🇷'),
    _CountryCode(code: '+593', name: 'EC', flag: '🇪🇨'),
    _CountryCode(code: '+591', name: 'BO', flag: '🇧🇴'),
    _CountryCode(code: '+1', name: 'US', flag: '🇺🇸'),
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber =>
      '$_selectedCountryCode${_phoneController.text.trim()}';

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 9) {
      setState(() => _errorMessage = 'Ingresa un número válido (mín. 9 dígitos).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _authService.verifyPhoneNumber(
      phoneNumber: _fullPhoneNumber,
      onVerificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verificación en Android; inicia sesión directamente.
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (_) {
          // El listener de AuthProvider se encargará del estado.
        }
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
        setState(() => _isLoading = false);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              verificationId: verificationId,
              phoneNumber: _fullPhoneNumber,
              resendToken: resendToken,
            ),
          ),
        );
      },
      onCodeAutoRetrievalTimeout: (String verificationId) {
        // No-op: el usuario puede seguir ingresando el código manualmente.
      },
    );
  }

  Future<void> _signInDemo() async {
    final selectedRole = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modo Demo / Prueba'),
        content: const Text('Selecciona el rol para ingresar directamente:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, AppConstants.rolPasajero),
            child: const Text('Pasajero'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, AppConstants.rolMototaxista),
            child: const Text('Mototaxista'),
          ),
        ],
      ),
    );

    if (selectedRole != null && mounted) {
      context.read<AuthProvider>().signInAsDemo(selectedRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // ── Ícono ──
              Icon(
                Icons.phone_android_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // ── Título ──
              Text(
                'Ingresa tu número',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Te enviaremos un código de verificación por SMS.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // ── Selector de país + input ──
              Row(
                children: [
                  // Dropdown de código de país
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountryCode,
                        items: _countryCodes.map((cc) {
                          return DropdownMenuItem(
                            value: cc.code,
                            child: Text(
                              '${cc.flag} ${cc.code}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCountryCode = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Campo de teléfono
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      decoration: InputDecoration(
                        hintText: '987 654 321',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      style: const TextStyle(fontSize: 18, letterSpacing: 1.5),
                    ),
                  ),
                ],
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

              // ── Botón Enviar ──
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _sendOtp,
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
                          'Enviar código',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Botón Modo Demo ──
              TextButton.icon(
                onPressed: _isLoading ? null : _signInDemo,
                icon: const Icon(Icons.flash_on_rounded),
                label: const Text('Ingresar en Modo Demo / Prueba'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper para códigos de país ──────────────────────────────────

class _CountryCode {
  final String code;
  final String name;
  final String flag;

  const _CountryCode({
    required this.code,
    required this.name,
    required this.flag,
  });
}
