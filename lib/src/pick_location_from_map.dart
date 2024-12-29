import 'dart:math';

import 'package:bound_location_picker/src/polygon_boundary.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';

import '../bound_location_picker.dart';
import 'map_picker_controller.dart';
import 'map_theme.dart';

class BoundLocationPicker extends StatefulWidget {
  ///initial camera position
  final LatLng initialCameraPosition;

  ///The callback that is called when the enablePickedButton==true and tapped.
  final Function(LatLng?)? onPickedLocation;

  ///Location picker update listener
  ///when map moved or ideal the listener updated
  final Function(LatLng?)? onLocationUpdateListener;

  ///circular boundary
  final CircleBoundary? circleBoundary;

  ///polygon boundary
  ///custom aria boundary
  final PolygonBoundary? polygonBoundary;

  ///location picker marker
  final AssetImage? locationPickerImage;

  ///location picker marker size/height
  final double locationPickerSize;

  ///location picker icon color
  final Color locationPickerColor;

  ///location picker color when disable/try to pick location outside of boundary
  final Color disableLocationPickerColor;

  ///boundary width if boundary exist
  final int boundaryWidth;

  ///boundary color if boundary exist
  final Color boundaryColor;

  ///inside boundary fill color
  ///boundary highlighted color
  final Color fillColor;

  ///if want to customized the google map theme
  ///the the [mapTheme] is used
  final String mapTheme;

  ///use [enablePickedButton] if want to enable/disable the pick location button
  final bool enablePickedButton;

  ///pick button shape
  final ShapeBorder? pickButtonShape;

  ///pick button style
  final Color pickButtonBackgroundColor;

  ///pick button style
  final Color disablePickButtonBackgroundColor;

  ///initial camera zom level
  final double initialCameraZoom;

  const BoundLocationPicker({
    super.key,
    required this.initialCameraPosition,
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
    this.initialCameraZoom = 14.4746,
  });

  @override
  State<BoundLocationPicker> createState() => _BoundLocationPickerState();
}

class _BoundLocationPickerState extends State<BoundLocationPicker> with SingleTickerProviderStateMixin {
  final logger = Logger();
  MapPickerController mapPickerController = MapPickerController();

  late GoogleMapController _controller;
  late CameraPosition cameraPosition;
  LatLng centerPoint = const LatLng(0, 0);
  late AnimationController animationController;
  late Animation<double> translateAnimation;
  LatLng? currentPosition;
  LatLng? lastPerfectPosition;
  bool enableToPickLocation = true;
  int polygonLength = 0;

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
    polygonLength = countPolygonLength();
    centerPoint = checkMapCenterPoint();
    cameraPosition = CameraPosition(
      target: centerPoint,
      zoom: widget.initialCameraZoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.enablePickedButton
          ? FloatingActionButton(
              onPressed: enableToPickLocation
                  ? () {
                      widget.onPickedLocation!(lastPerfectPosition!);
                    }
                  : null,
              backgroundColor: enableToPickLocation ? widget.pickButtonBackgroundColor : widget.disablePickButtonBackgroundColor,
              shape: widget.pickButtonShape,
              child: Icon(
                enableToPickLocation ? Icons.check_rounded : Icons.close_rounded,
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
                  lastPerfectPosition = centerPoint;
                },
                circles: widget.circleBoundary == null
                    ? {}
                    : {
                        Circle(
                          circleId: const CircleId("id"),
                          center: centerPoint,
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
                        : polygonLength <= 2
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
                      enableToPickLocation = distance <= widget.circleBoundary!.radius;
                    });

                    setState(() {
                      currentPosition = center;
                    });

                    if (distance <= widget.circleBoundary!.radius) {
                      lastPerfectPosition = cameraPosition.target;
                    }
                  } else {
                    if ((widget.polygonBoundary != null) && polygonLength > 2) {
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
                              image: AssetImage(widget.locationPickerImage!.assetName),
                              height: widget.locationPickerSize,
                              color: enableToPickLocation ? null : widget.disableLocationPickerColor,
                            )
                          : Icon(
                              Icons.location_on,
                              size: widget.locationPickerSize,
                              color: enableToPickLocation ? widget.locationPickerColor : widget.disableLocationPickerColor,
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

      if ((vertex1.latitude > point.latitude) != (vertex2.latitude > point.latitude)) {
        double intersectLongitude =
            vertex1.longitude + (point.latitude - vertex1.latitude) * (vertex2.longitude - vertex1.longitude) / (vertex2.latitude - vertex1.latitude);
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
    LatLng position = widget.initialCameraPosition;

    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((position.latitude - lat) * p) / 2 + c(lat * p) * c(position.latitude * p) * (1 - c((position.longitude - lng) * p)) / 2;
    distance = (12742 * asin(sqrt(a))) * 1000;

    return distance;
  }

  LatLng getCenterPoint(List<LatLng> points) {
    double totalLat = 0;
    double totalLng = 0;

    for (LatLng point in points) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }

    double centerLat = totalLat / points.length;
    double centerLng = totalLng / points.length;

    return LatLng(centerLat, centerLng);
  }

  LatLng checkMapCenterPoint() {
    if (widget.circleBoundary == null && widget.polygonBoundary != null) {
      if (polygonLength <= 2) {
        logger.e(
          "Polygon line error",
          error: "If you use polygonBoundary, then you must need to provide a polygonList with non repeated more than 2 LatLng.",
        );
        return widget.initialCameraPosition;
      }
      return getCenterPoint(widget.polygonBoundary!.polygonList);
    }
    return widget.initialCameraPosition;
  }

  int countPolygonLength() {
    return widget.polygonBoundary?.polygonList.length ?? 0;
  }
}
