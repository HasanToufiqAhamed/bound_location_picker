import 'dart:math';

import 'package:bound_location_picker/src/polygon_boundary.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'circle_boundary.dart';
import 'map_picker_controller.dart';
import 'map_theme.dart';

class BoundLocationPicker extends StatefulWidget {
  final LatLng centerPoint;
  final Function(LatLng?)? onPickedLocation;
  final Function(LatLng?)? onLocationUpdateListener;
  final CircleBoundary? circleBoundary;
  final PolygonBoundary? polygonBoundary;
  final AssetImage? locationPickerImage;
  final double locationPickerSize;
  final Color locationPickerColor;
  final Color disableLocationPickerColor;
  final int boundaryWidth;
  final Color boundaryColor;
  final Color fillColor;
  final String mapTheme;
  final bool enablePickedButton;
  final ShapeBorder? pickButtonShape;
  final Color pickButtonBackgroundColor;
  final Color disablePickButtonBackgroundColor;

  const BoundLocationPicker({
    super.key,
    required this.centerPoint,
    this.onPickedLocation,
    this.onLocationUpdateListener,
    this.circleBoundary,
    this.polygonBoundary,
    this.locationPickerImage,
    this.locationPickerSize = 42,
    this.locationPickerColor = Colors.green,
    this.disableLocationPickerColor = Colors.grey,
    this.boundaryWidth = 2,
    this.boundaryColor = Colors.red,
    this.fillColor = const Color(0x1A1A4FFF),
    this.mapTheme = MapTheme.theme,
    this.enablePickedButton = false,
    this.pickButtonShape,
    this.pickButtonBackgroundColor = Colors.blueAccent,
    this.disablePickButtonBackgroundColor = Colors.grey,
  });

  @override
  State<BoundLocationPicker> createState() => _BoundLocationPickerState();
}

class _BoundLocationPickerState extends State<BoundLocationPicker>
    with SingleTickerProviderStateMixin {
  MapPickerController mapPickerController = MapPickerController();

  late GoogleMapController _controller;

  late CameraPosition cameraPosition;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    mapPickerController.onMapMove = mapMoving;
    mapPickerController.onMapIdle = mapFinishedMoving;

    translateAnimation = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.ease,
      ),
    );
    cameraPosition = CameraPosition(
      target: widget.centerPoint,
      zoom: 14.4746,
    );
  }

  late AnimationController animationController;
  late Animation<double> translateAnimation;

  /// Start of animation when map starts dragging by user, checks the state
  /// before firing animation, thus optimizing for rendering purposes
  void mapMoving() {
    if (!animationController.isAnimating && !animationController.isCompleted) {
      animationController.forward();
    }
  }

  /// down the Pin whenever the map is released and goes to idle position
  void mapFinishedMoving() {
    animationController.reverse();
  }

  LatLng? currentPosition;
  LatLng? lastPerfectPosition;
  bool enableToPickLocation = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.enablePickedButton
          ? FloatingActionButton(
              onPressed: () {
                widget.onPickedLocation!(lastPerfectPosition!);
              },
              backgroundColor: enableToPickLocation
                  ? widget.pickButtonBackgroundColor
                  : widget.disablePickButtonBackgroundColor,
              shape: widget.pickButtonShape,
              child: Icon(
                enableToPickLocation
                    ? Icons.check_rounded
                    : Icons.close_rounded,
                color: Colors.white,
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Stack(
            alignment: Alignment.center,
            children: [
              GoogleMap(
                initialCameraPosition: cameraPosition,
                onMapCreated: (GoogleMapController controller) {
                  _controller = controller;
                  lastPerfectPosition = widget.centerPoint;
                },
                circles: widget.circleBoundary == null
                    ? {}
                    : {
                        Circle(
                          circleId: const CircleId("id"),
                          center: widget.centerPoint,
                          radius: widget.circleBoundary!.radius,
                          strokeWidth: widget.boundaryWidth,
                          strokeColor: widget.boundaryColor,
                          fillColor: widget.fillColor,
                        )
                      },
                polygons: widget.circleBoundary != null
                    ? {}
                    : widget.polygonBoundary?.polygonList == null
                        ? {}
                        : {
                            Polygon(
                              polygonId: const PolygonId("id"),
                              points: widget.polygonBoundary?.polygonList ?? [],
                              strokeWidth: widget.boundaryWidth,
                              strokeColor: widget.boundaryColor,
                              fillColor: widget.fillColor,
                            )
                          },
                onCameraMove: (cameraPosition) {
                  this.cameraPosition = cameraPosition;
                  final center = cameraPosition.target;

                  if (widget.circleBoundary != null) {
                    final distance = _getDistance(
                      lat: center.latitude,
                      lng: center.longitude,
                    );

                    setState(() {
                      enableToPickLocation =
                          distance <= widget.circleBoundary!.radius;
                    });

                    setState(() {
                      currentPosition = center;
                    });

                    if (distance <= widget.circleBoundary!.radius) {
                      lastPerfectPosition = cameraPosition.target;
                    }
                  } else {
                    if (widget.polygonBoundary != null) {
                      final isInside = _isPointInPolygon(
                        point: center,
                        polygon: widget.polygonBoundary!.polygonList,
                      );

                      setState(() {
                        enableToPickLocation = isInside;
                      });

                      setState(() {
                        currentPosition = center;
                      });

                      if (isInside) {
                        lastPerfectPosition = cameraPosition.target;
                      }
                    }
                  }
                },
                onCameraMoveStarted: () {
                  widget.onLocationUpdateListener!(null);
                  mapPickerController.onMapMove!();
                  animationController.forward();
                },
                onCameraIdle: () async {
                  if (!enableToPickLocation && lastPerfectPosition != null) {
                    _controller.animateCamera(
                      CameraUpdate.newLatLng(lastPerfectPosition!),
                    );
                  }
                  mapPickerController.onMapIdle!();
                  animationController.reverse();
                  if (enableToPickLocation) {
                    widget.onLocationUpdateListener!(lastPerfectPosition!);
                  }
                },
                indoorViewEnabled: false,
                style: widget.mapTheme,
                mapType: MapType.normal,
                zoomControlsEnabled: false,
              ),
              Visibility(
                visible: enableToPickLocation,
                child: Container(
                  height: 2,
                  width: 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.locationPickerColor,
                  ),
                ),
              ),
              Positioned(
                bottom: constraints.maxHeight * 0.5,
                child: AnimatedBuilder(
                  animation: animationController,
                  builder: (context, snapshot) {
                    return Transform.translate(
                      offset: Offset(0, -15 * translateAnimation.value),
                      child: widget.locationPickerImage != null
                          ? Image(
                              image: AssetImage(
                                  widget.locationPickerImage!.assetName),
                              height: widget.locationPickerSize,
                              color: enableToPickLocation
                                  ? null
                                  : widget.disableLocationPickerColor,
                            )
                          : Icon(
                              Icons.location_on,
                              size: widget.locationPickerSize,
                              color: enableToPickLocation
                                  ? widget.locationPickerColor
                                  : widget.disableLocationPickerColor,
                            ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isPointInPolygon({
    required LatLng point,
    required List<LatLng> polygon,
  }) {
    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      LatLng vertex1 = polygon[i];
      LatLng vertex2 = polygon[(i + 1) % polygon.length];

      if ((vertex1.latitude > point.latitude) !=
          (vertex2.latitude > point.latitude)) {
        double intersectLongitude = vertex1.longitude +
            (point.latitude - vertex1.latitude) *
                (vertex2.longitude - vertex1.longitude) /
                (vertex2.latitude - vertex1.latitude);
        if (point.longitude < intersectLongitude) {
          intersections++;
        }
      }
    }

    return (intersections % 2 == 1);
  }

  num _getDistance({
    required num lat,
    required num lng,
  }) {
    num distance = 0;
    LatLng position = widget.centerPoint;

    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((position.latitude - lat) * p) / 2 +
        c(lat * p) *
            c(position.latitude * p) *
            (1 - c((position.longitude - lng) * p)) /
            2;
    distance = (12742 * asin(sqrt(a))) * 1000;

    return distance;
  }
}
