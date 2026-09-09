import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:py55/features/auth/auth_provider.dart';

/// Pantalla para solicitar el número de celular de contacto a usuarios de Google Sign-In.
class CompletePhoneScreen extends StatefulWidget {
  final String selectedRole;

  const CompletePhoneScreen({
    super.key,
    required this.selectedRole,
  });

  @override
  State<CompletePhoneScreen> createState() => _CompletePhoneScreenState();
}

class _CompletePhoneScreenState extends State<CompletePhoneScreen> {
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+51'; // Perú por defecto
  bool _isLoading = false;
  String? _errorMessage;

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

  Future<void> _submitPhone() async {
    final phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty || phoneText.length < 9) {
      setState(() {
        _errorMessage = 'Ingresa un número de celular válido (mín. 9 dígitos).';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context
          .read<AuthProvider>()
          .saveUserWithRoleAndPhone(widget.selectedRole, _fullPhoneNumber);
      // El estado del AuthProvider cambiará a needsVerificationUpload
      // y la navegación se resolverá mediante AuthWrapper o pop.
      if (mounted && Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al guardar el teléfono: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completar Perfil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              Icon(
                Icons.contact_phone_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),

              Text(
                'Número de celular de contacto',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Por seguridad, ingresa un número de teléfono de contacto. '
                'Se utilizará para identificarte en tus viajes y en alertas de pánico.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // Selector de país + Campo de número
              Row(
                children: [
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

              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submitPhone,
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
                          'Guardar y Continuar',
                          style: TextStyle(fontSize: 16),
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
