import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:bound_location_picker/bound_location_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: BoundLocationPicker(
          initialCameraPosition: const LatLng(24.540725, 89.631088),
          onPickedLocation: (LatLng? location) {
            ///TODO do something using location
          },
          onLocationUpdateListener: (LatLng? location) {
            ///TODO do something with current location
          },
          locationPickerImage: const AssetImage("assets/pin_point.png"),
          circleBoundary: CircleBoundary(radius: 800),
          enablePickedButton: true,
        ),
      ),
    );
  }
}