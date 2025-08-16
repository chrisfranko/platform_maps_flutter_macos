// lib/platform_maps_flutter_macos.dart
// Federated macOS impl for platform_maps_flutter using flutter_macos_maps.

library platform_maps_flutter_macos;

import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/widgets.dart';
import 'package:platform_maps_flutter_platform_interface/platform_maps_flutter_platform_interface.dart';
import 'package:flutter_macos_maps/flutter_macos_maps.dart' as mac;

class PlatformMapsFlutterMacOS extends PlatformMapsPlatform {
  static void registerWith() {
    PlatformMapsPlatform.instance = PlatformMapsFlutterMacOS();
  }

  @override
  PlatformBitmapDescriptor createBitmapDescriptor() =>
      PlatformBitmapDescriptor.implementation();

  @override
  PlatformCameraUpdate createPlatformCameraUpdate() =>
      PlatformCameraUpdate.implementation();

  @override
  PlatformMapsPlatformWidget createPlatformMapsPlatformWidget(
    PlatformMapsPlatformWidgetCreationParams params,
  ) =>
      _MacOSPlatformWidget(params);
}

// ---------------- Widget builder ----------------

class _MacOSPlatformWidget extends PlatformMapsPlatformWidget {
  _MacOSPlatformWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => _MacContainer(params);
}

class _MacContainer extends StatefulWidget {
  const _MacContainer(this.params, {super.key});
  final PlatformMapsPlatformWidgetCreationParams params;

  @override
  State<_MacContainer> createState() => _MacContainerState();
}

class _MacContainerState extends State<_MacContainer> {
  mac.FlutterMacosMapsController? _c;

  // Live mirrors of what we've applied to the native map
  Map<String, Marker> _markers = {};
  Map<String, Polyline> _polylines = {};
  Map<String, Polygon> _polygons = {};
  Map<String, Circle> _circles = {};

  // Native overlay IDs returned by the mac plugin
  final Map<String, String> _polylineOverlayIds = {};
  final Map<String, String> _polygonOverlayIds = {};
  final Map<String, String> _circleOverlayIds = {};

  StreamSubscription? _tapSub, _longSub, _annTapSub, _regionSub;
  Timer? _idleDebounce;

  @override
  void dispose() {
    _tapSub?.cancel();
    _longSub?.cancel();
    _annTapSub?.cancel();
    _regionSub?.cancel();
    _idleDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.params;
    final init = p.initialCameraPosition;

    return mac.FlutterMacosMapsView(
      initialCamera: mac.CameraPosition(
        target: mac.LatLng(init.target.latitude, init.target.longitude),
        latDelta: _deltaFromZoom(init.zoom),
        lonDelta: _deltaFromZoom(init.zoom),
        heading: init.bearing,
        pitch: init.tilt,
      ),
      onCreated: (controller) async {
        _c = controller;

        // map type
        await _c!.setMapType(_toMacType(p.mapType));

        // my location
        if (p.myLocationEnabled) {
          await _c!.showsUserLocation(true);
        }

        // seed layers
        await _syncMarkers(p.markers);
        await _syncPolylines(p.polylines);
        await _syncPolygons(p.polygons);
        await _syncCircles(p.circles);

        // events
        _tapSub = _c!.onTap.listen((latLng) {
          p.onTap?.call(LatLng(latLng.lat, latLng.lon));
        });

        _longSub = _c!.onLongPress.listen((latLng) {
          p.onLongPress?.call(LatLng(latLng.lat, latLng.lon));
        });

        _annTapSub = _c!.onAnnotationTap.listen((id) {
          // if the platform interface exposes a marker onTap via the Marker object,
          // call it here by looking up the marker:
          final m = _markers[id];
          m?.onTap?.call();
        });

        _regionSub = _c!.onRegionChanged.listen((e) {
          // onCameraMove
          widget.params.onCameraMove?.call(
            CameraPosition(
              target: LatLng(e.camera.target.lat, e.camera.target.lon),
              zoom: _zoomFromDeltas(e.camera.latDelta, e.camera.lonDelta),
              tilt: e.camera.pitch ?? 0.0,
              bearing: e.camera.heading ?? 0.0,
            ),
          );

          // Debounced onCameraIdle
          _idleDebounce?.cancel();
          _idleDebounce = Timer(const Duration(milliseconds: 180), () {
            widget.params.onCameraIdle?.call();
          });
        });

        // controller to caller
        p.onMapCreated?.call(_MacController(_c!, this));
      },
    );
  }

  @override
  void didUpdateWidget(covariant _MacContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_c == null) return;

    final prev = oldWidget.params;
    final next = widget.params;

    // Map type
    if (prev.mapType != next.mapType) {
      _c!.setMapType(_toMacType(next.mapType));
    }

    // My location
    if (prev.myLocationEnabled != next.myLocationEnabled) {
      _c!.showsUserLocation(next.myLocationEnabled);
    }

    // Markers / Polylines / Polygons / Circles
    unawaited(_syncMarkers(next.markers));
    unawaited(_syncPolylines(next.polylines));
    unawaited(_syncPolygons(next.polygons));
    unawaited(_syncCircles(next.circles));
  }

  // ---------------- Diffs & sync ----------------

  Future<void> _syncMarkers(Set<Marker> newSet) async {
    if (_c == null) return;
    final newMap = {for (final m in newSet) m.markerId.value: m};

    // removals
    for (final id in _markers.keys.where((k) => !newMap.containsKey(k)).toList()) {
      await _c!.removeAnnotation(id);
      _markers.remove(id);
    }

    // adds/updates
    for (final entry in newMap.entries) {
      final id = entry.key;
      final m = entry.value;
      final old = _markers[id];

      if (old == null) {
        await _c!.addAnnotation(
          id: id,
          position: mac.LatLng(m.position.latitude, m.position.longitude),
          title: m.infoWindow?.title,
          subtitle: m.infoWindow?.snippet,
        );
        _markers[id] = m;
        continue;
      }

      // update if changed (position/title/snippet)
      final changed = old.position != m.position ||
          (old.infoWindow?.title != m.infoWindow?.title) ||
          (old.infoWindow?.snippet != m.infoWindow?.snippet);
      if (changed) {
        await _c!.removeAnnotation(id);
        await _c!.addAnnotation(
          id: id,
          position: mac.LatLng(m.position.latitude, m.position.longitude),
          title: m.infoWindow?.title,
          subtitle: m.infoWindow?.snippet,
        );
        _markers[id] = m;
      }
    }
  }

  Future<void> _syncPolylines(Set<Polyline> newSet) async {
    if (_c == null) return;
    final next = {for (final p in newSet) p.polylineId.value: p};

    // removals
    for (final id in _polylines.keys.where((k) => !next.containsKey(k)).toList()) {
      final overlayId = _polylineOverlayIds.remove(id);
      if (overlayId != null) await _c!.removeOverlay(overlayId);
      _polylines.remove(id);
    }

    // adds/updates (simple: remove & re-add if changed)
    for (final entry in next.entries) {
      final id = entry.key;
      final p = entry.value;
      final old = _polylines[id];

      if (old == null || !_polylineEquals(old, p)) {
        final existingOverlay = _polylineOverlayIds.remove(id);
        if (existingOverlay != null) await _c!.removeOverlay(existingOverlay);

        final overlayId = await _c!.addPolyline(
          points: p.points.map((pt) => mac.LatLng(pt.latitude, pt.longitude)).toList(),
          color: _toArgb(p.color),
          width: p.width.toDouble(),
          id: id,
        );
        _polylineOverlayIds[id] = overlayId;
        _polylines[id] = p;
      }
    }
  }

  Future<void> _syncPolygons(Set<Polygon> newSet) async {
    if (_c == null) return;
    final next = {for (final p in newSet) p.polygonId.value: p};

    // removals
    for (final id in _polygons.keys.where((k) => !next.containsKey(k)).toList()) {
      final overlayId = _polygonOverlayIds.remove(id);
      if (overlayId != null) await _c!.removeOverlay(overlayId);
      _polygons.remove(id);
    }

    // adds/updates
    for (final entry in next.entries) {
      final id = entry.key;
      final p = entry.value;
      final old = _polygons[id];

      if (old == null || !_polygonEquals(old, p)) {
        final existingOverlay = _polygonOverlayIds.remove(id);
        if (existingOverlay != null) await _c!.removeOverlay(existingOverlay);

        final overlayId = await _c!.addPolygon(
          points: p.points.map((pt) => mac.LatLng(pt.latitude, pt.longitude)).toList(),
          strokeColor: _toArgb(p.strokeColor),
          fillColor: _toArgb(p.fillColor),
          width: p.strokeWidth.toDouble(),
          id: id,
        );
        _polygonOverlayIds[id] = overlayId;
        _polygons[id] = p;
      }
    }
  }

  Future<void> _syncCircles(Set<Circle> newSet) async {
    if (_c == null) return;
    final next = {for (final c in newSet) c.circleId.value: c};

    // removals
    for (final id in _circles.keys.where((k) => !next.containsKey(k)).toList()) {
      final overlayId = _circleOverlayIds.remove(id);
      if (overlayId != null) await _c!.removeOverlay(overlayId);
      _circles.remove(id);
    }

    // adds/updates
    for (final entry in next.entries) {
      final id = entry.key;
      final c = entry.value;
      final old = _circles[id];

      if (old == null || !_circleEquals(old, c)) {
        final existingOverlay = _circleOverlayIds.remove(id);
        if (existingOverlay != null) await _c!.removeOverlay(existingOverlay);

        final overlayId = await _c!.addCircle(
          center: mac.LatLng(c.center.latitude, c.center.longitude),
          radius: c.radius,
          strokeColor: _toArgb(c.strokeColor),
          fillColor: _toArgb(c.fillColor),
          width: c.strokeWidth.toDouble(),
          id: id,
        );
        _circleOverlayIds[id] = overlayId;
        _circles[id] = c;
      }
    }
  }

  // ---------------- Helpers ----------------

  mac.MapType _toMacType(MapType t) {
    switch (t) {
      case MapType.hybrid:
        return mac.MapType.hybrid;
      case MapType.satellite:
        return mac.MapType.satellite;
      case MapType.normal:
      default:
        return mac.MapType.standard;
    }
  }

  int _toArgb(Color c) => c.value;

  // crude zoom<->span heuristics; tweak if you want closer parity
  double _deltaFromZoom(double z) {
    final clamped = z.clamp(3.0, 20.0);
    return (20.0 - clamped) * 0.02 + 0.005;
  }

  double _zoomFromDeltas(double? latDelta, double? lonDelta) {
    final d = ((latDelta ?? 0.05) + (lonDelta ?? 0.05)) / 2.0;
    final z = 20.0 - ((d - 0.005) / 0.02);
    return z;
  }

  bool _polylineEquals(Polyline a, Polyline b) =>
      a.points == b.points && a.color == b.color && a.width == b.width;

  bool _polygonEquals(Polygon a, Polygon b) =>
      a.points == b.points &&
      a.strokeColor == b.strokeColor &&
      a.fillColor == b.fillColor &&
      a.strokeWidth == b.strokeWidth;

  bool _circleEquals(Circle a, Circle b) =>
      a.center == b.center &&
      a.radius == b.radius &&
      a.strokeColor == b.strokeColor &&
      a.fillColor == b.fillColor &&
      a.strokeWidth == b.strokeWidth;
}

// ---------------- Controller bridge ----------------

class _MacController extends PlatformMapsPlatformController {
  _MacController(this._c, this._state);
  final mac.FlutterMacosMapsController _c;
  final _MacContainerState _state;

  @override
  Future<void> animateCamera(PlatformCameraUpdate update) =>
      _applyCameraUpdate(update, animated: true);

  @override
  Future<void> moveCamera(PlatformCameraUpdate update) =>
      _applyCameraUpdate(update, animated: false);

  Future<void> _applyCameraUpdate(PlatformCameraUpdate update,
      {required bool animated}) async {
    // Works with the common PlatformCameraUpdate JSON shape.
    final data = update.toJson();
    final type = data['type'];

    if (type == 'newCameraPosition') {
      final cp = data['cameraPosition'] as Map;
      final tgt = cp['target'] as Map;
      final zoom = (cp['zoom'] as num?)?.toDouble();
      await _c.setCamera(
        mac.CameraPosition(
          target: mac.LatLng(
            (tgt['latitude'] as num).toDouble(),
            (tgt['longitude'] as num).toDouble(),
          ),
          latDelta: zoom != null ? _state._deltaFromZoom(zoom) : null,
          lonDelta: zoom != null ? _state._deltaFromZoom(zoom) : null,
          heading: (cp['bearing'] as num?)?.toDouble(),
          pitch: (cp['tilt'] as num?)?.toDouble(),
        ),
        animated: animated,
      );
      return;
    }

    if (type == 'newLatLng') {
      final tgt = data['target'] as Map;
      await _c.setCamera(
        mac.CameraPosition(
          target: mac.LatLng(
            (tgt['latitude'] as num).toDouble(),
            (tgt['longitude'] as num).toDouble(),
          ),
        ),
        animated: animated,
      );
      return;
    }

    if (type == 'newLatLngZoom') {
      final tgt = data['target'] as Map;
      final zoom = (data['zoom'] as num).toDouble();
      await _c.setCamera(
        mac.CameraPosition(
          target: mac.LatLng(
            (tgt['latitude'] as num).toDouble(),
            (tgt['longitude'] as num).toDouble(),
          ),
          latDelta: _state._deltaFromZoom(zoom),
          lonDelta: _state._deltaFromZoom(zoom),
        ),
        animated: animated,
      );
      return;
    }

    // (Other update types can be added here as needed.)
  }

  // These are optional in the interface; wire up when your plugin exposes them.
  @override
  Future<LatLngBounds> getVisibleRegion() async {
    // If you add a getVisibleRegion() to flutter_macos_maps, forward it here.
    // For now, throw to surface that it's not supported yet.
    throw UnimplementedError('getVisibleRegion is not supported on macOS yet.');
  }

  @override
  Future<void> showMarkerInfoWindow(MarkerId markerId) async {
    // Hook to callouts in your plugin if/when added.
  }

  @override
  Future<void> hideMarkerInfoWindow(MarkerId markerId) async {}

  @override
  Future<bool> isMarkerInfoWindowShown(MarkerId markerId) async => false;

  @override
  Future<List<int>?> takeSnapshot() async => null;
}
