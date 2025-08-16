import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Use ONLY the platform interface in this example:
import 'package:platform_maps_flutter_platform_interface/platform_maps_flutter_platform_interface.dart'
    as fed;

// Import your macOS implementation package just to force registration:
import 'package:platform_maps_flutter_macos/platform_maps_flutter_macos.dart'
    as macos_impl;

void main() {
  // Ensure the macOS implementation is registered in this standalone example.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    macos_impl.PlatformMapsFlutterMacOS.registerWith();
  }
  runApp(const MaterialApp(home: Demo()));
}

class Demo extends StatefulWidget {
  const Demo({super.key});
  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  fed.PlatformMapController? _controller;
  late final fed.PlatformCameraUpdate _cam; // factory for CameraUpdates

  final fed.LatLng _apple = const fed.LatLng(37.3349, -122.0090);

  Set<fed.Marker> markers = {
    const fed.Marker(
      markerId: fed.MarkerId('apple-park'),
      position: fed.LatLng(37.3349, -122.0090),
      infoWindow: fed.InfoWindow(title: 'Apple Park'),
    ),
  };

  Set<fed.Polyline> polylines = {
    fed.Polyline(
      polylineId: fed.PolylineId('route'),
      color: Colors.orange,
      width: 4,
      points: const [
        fed.LatLng(37.3349, -122.0090),
        fed.LatLng(37.3318, -122.0300),
        fed.LatLng(37.3269, -122.0325),
      ],
    ),
  };

  Set<fed.Polygon> polygons = {
    fed.Polygon(
      polygonId: fed.PolygonId('area'),
      strokeColor: Colors.indigo,
      fillColor: Colors.indigoAccent.withOpacity(.2),
      strokeWidth: 2,
      points: const [
        fed.LatLng(37.3360, -122.0180),
        fed.LatLng(37.3360, -121.9980),
        fed.LatLng(37.3280, -121.9980),
        fed.LatLng(37.3280, -122.0180),
      ],
    ),
  };

  Set<fed.Circle> circles = {
    fed.Circle(
      circleId: fed.CircleId('ring'),
      center: const fed.LatLng(37.3349, -122.0090),
      radius: 300,
      strokeWidth: 2,
      strokeColor: Colors.green,
      fillColor: Colors.green.withOpacity(.2),
    )
  };

  @override
  void initState() {
    super.initState();
    // Now that we’ve registered, the instance is non-null.
    _cam = fed.PlatformMapsPlatform.instance!
        .createPlatformCameraUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final params = fed.PlatformMapsPlatformWidgetCreationParams(
      initialCameraPosition: const fed.CameraPosition(
        target: fed.LatLng(37.3349, -122.0090),
        zoom: 14,
        tilt: 0,
        bearing: 0,
      ),
      mapType: fed.MapType.normal,
      markers: markers,
      polylines: polylines,
      polygons: polygons,
      circles: circles,
      onMapCreated: (c) => _controller = c,
      onTap: (pos) {
        setState(() {
          markers = {
            ...markers,
            fed.Marker(
              markerId: fed.MarkerId('m${markers.length}'),
              position: pos,
            ),
          };
        });
      },
      onCameraMove: (cp) => debugPrint('zoom=${cp.zoom} center=${cp.target}'),
      onCameraIdle: () => debugPrint('idle'),
    );

    // Build the widget via the platform interface using the registered macOS impl.
    final widget = fed.PlatformMapsPlatform.instance!
        .createPlatformMapsPlatformWidget(params)
        .build(context);

    return Scaffold(
      appBar: AppBar(title: const Text('platform interface (macOS) example')),
      body: widget,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'toApple',
            onPressed: () => _controller?.animateCamera(
              _cam.newLatLngZoom(_apple, 15),
            ),
            label: const Text('Go to Apple'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'zoomOut',
            onPressed: () => _controller?.animateCamera(_cam.zoomOut()),
            label: const Text('Zoom out'),
          ),
        ],
      ),
    );
  }
}
