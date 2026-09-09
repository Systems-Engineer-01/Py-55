import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:py55/core/theme.dart';
import 'package:py55/features/ride_request/places_service.dart';

/// Callback emitido cuando el usuario selecciona un destino de la lista.
typedef OnDestinationSelected = void Function(
    LatLng location, String addressName);

/// Widget que ofrece un campo de búsqueda de destino con autocompletado debounced (400ms)
/// usando la API de Google Places filtrando por Perú.
class DestinationSearchBar extends StatefulWidget {
  final OnDestinationSelected onDestinationSelected;
  final PlacesService? placesService;

  const DestinationSearchBar({
    super.key,
    required this.onDestinationSelected,
    this.placesService,
  });

  @override
  State<DestinationSearchBar> createState() => _DestinationSearchBarState();
}

class _DestinationSearchBarState extends State<DestinationSearchBar> {
  late final PlacesService _placesService;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  List<PlacePrediction> _predictions = [];
  bool _isSearching = false;
  bool _showDropdown = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _placesService = widget.placesService ?? PlacesService();
    _controller.addListener(_onSearchChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showDropdown = false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = _controller.text;

    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _isSearching = false;
        _showDropdown = false;
        _errorMessage = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _isSearching = true;
        _errorMessage = null;
        _showDropdown = true;
      });

      try {
        final results =
            await _placesService.getAutocompleteSuggestions(query);
        if (!mounted) return;

        setState(() {
          _predictions = results;
          _isSearching = false;
          if (results.isEmpty) {
            _errorMessage = 'No se encontraron resultados en Perú';
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _predictions = [];
          _isSearching = false;
          _errorMessage = 'Error de conexión al buscar';
        });
      }
    });
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    _focusNode.unfocus();
    setState(() {
      _showDropdown = false;
      _isSearching = true;
      _controller.text = prediction.mainText;
    });

    final details =
        await _placesService.getPlaceDetails(prediction.placeId);

    if (!mounted) return;

    setState(() => _isSearching = false);

    if (details != null) {
      widget.onDestinationSelected(
        details.location,
        details.formattedAddress,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No se pudieron obtener las coordenadas del lugar seleccionado.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campo de búsqueda de destino
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar destino por nombre...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.primaryColor),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _predictions = [];
                              _showDropdown = false;
                              _errorMessage = null;
                            });
                          },
                        )
                      : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),

        // Lista desplegable de sugerencias
        if (_showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _buildDropdownContent(),
          ),
      ],
    );
  }

  Widget _buildDropdownContent() {
    if (_isSearching && _predictions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Buscando ubicaciones en Perú...',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _predictions.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final item = _predictions[index];
        return ListTile(
          dense: true,
          leading:
              const Icon(Icons.location_on_outlined, color: Colors.redAccent),
          title: Text(
            item.mainText,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: item.secondaryText.isNotEmpty
              ? Text(
                  item.secondaryText,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          onTap: () => _selectPlace(item),
        );
      },
    );
  }
}
