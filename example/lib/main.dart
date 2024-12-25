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
          centerPoint: const LatLng(24.540725, 89.631088),
          onPickedLocation: (location) {
            ///TODO pick your location
            print(
                '📍 picked location is:: ${location?.latitude}, ${location?.longitude}');
          },
          onLocationUpdateListener: (location) {
            ///TODO do something with current location
            print(
                '📍 listening location is:: ${location?.latitude}, ${location?.longitude}');
          },
          locationPickerImage: const AssetImage("assets/pin_point.png"),
          // polygonBoundary: PolygonBoundary(polygonList: const [
          //   LatLng(24.544237, 89.625686),
          //   LatLng(24.545926, 89.628100),
          //   LatLng(24.546264, 89.632780),
          //   LatLng(24.543561, 89.636272),
          //   LatLng(24.540419, 89.633746),
          //   LatLng(24.533694, 89.636903),
          //   LatLng(24.533062, 89.632818),
          //   LatLng(24.539882, 89.629538),
          //   LatLng(24.540144, 89.628278),
          //   LatLng(24.541073, 89.627921),
          //   LatLng(24.542552, 89.625571),
          //   // LatLng(23.829314, 90.364097),
          //   // LatLng(23.829547, 90.372467),
          //   // LatLng(23.830201, 90.376576),
          //   // LatLng(23.828380, 90.376984),
          //   // LatLng(23.825696, 90.377086),
          //   // LatLng(23.822334, 90.377571),
          //   // LatLng(23.820280, 90.365322),
          //   // LatLng(23.822186, 90.364511),
          // ]),
          circleBoundary: CircleBoundary(radius: 800),
          enablePickedButton: true,
        ),
      ),
    );
  }
}
