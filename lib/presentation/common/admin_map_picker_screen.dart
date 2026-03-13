import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quest_guide/presentation/common/premium_button.dart';

class AdminMapPickerScreen extends StatefulWidget {
  final LatLng initialPosition;
  final LatLng? cityCenter;

  const AdminMapPickerScreen({
    super.key,
    required this.initialPosition,
    this.cityCenter,
  });

  @override
  State<AdminMapPickerScreen> createState() => _AdminMapPickerScreenState();
}

class _AdminMapPickerScreenState extends State<AdminMapPickerScreen> {
  late LatLng _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedPosition = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Если локация еще не выбрана, открываем карту на центре выбранного города.
    final initialTarget = (_selectedPosition.latitude == 0.0 &&
            _selectedPosition.longitude == 0.0)
        ? (widget.cityCenter ?? const LatLng(51.169392, 71.449074))
        : _selectedPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите точку'),
        leading: BackButton(
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 14.0,
            ),
            onTap: _onMapTapped,
            markers: {
              if (_selectedPosition.latitude != 0.0 ||
                  _selectedPosition.longitude != 0.0)
                Marker(
                  markerId: const MarkerId('selected_location'),
                  position: _selectedPosition,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed),
                ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: max(32, MediaQuery.paddingOf(context).bottom + 16),
            child: PremiumButton(
              text: 'Сохранить координаты',
              icon: Icons.check,
              onPressed: () {
                context.pop(_selectedPosition);
              },
            ),
          ),
        ],
      ),
    );
  }
}
