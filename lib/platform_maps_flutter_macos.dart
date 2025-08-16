// lib/platform_maps_flutter_macos.dart
// Federated macOS implementation for platform_maps_flutter using flutter_macos_maps.

library platform_maps_flutter_macos;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:platform_maps_flutter_platform_interface/platform_maps_flutter_platform_interface.dart';
import 'package:flutter_macos_maps/flutter_macos_maps.dart' as mac;

/// Auto-registered entrypoint (pubspec -> flutter.plugin.platforms.macos.dartPluginClass)
class PlatformMapsFlutterMacOS extends PlatformMapsPlatform {
  static void registerWith() {
    PlatformMapsPlatform.instance = PlatformMapsFlutterMacOS();
  }

  @override
  PlatformBitmapDescriptor createBitmapDescriptor() =>
      _MacPlatformBitmapDescriptor();

  @override
  PlatformCameraUpdate createPlatformCameraUpdate() =>
      _MacPlatformCameraUpdate();

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
  const _MacContainer(this.params);
  final PlatformMapsPlatformWidgetCreationParams params;

  @override
  State<_MacContainer> createState() => _MacContainerState();
}

class _MacContainerState extends State<_MacContainer> {
  mac.FlutterMacosMapsController? _c;

  // Mirrors of applied state (for diffs)
  final Map<String, Marker> _markers = {};
  final Map<String, Polyline> _polylines = {};
  final Map<String, Polygon> _polygons = {};
  final Map<String, Circle> _circles = {};

  // Overlay IDs returned by mac plugin (if you expose IDs on add*)
  final Map<String, String> _polylineOverlayIds = {};
  final Map<String, String> _polygonOverlayIds = {};
  final Map<String, String> _circleOverlayIds = {};

  // Camera tracking (for zoomIn/zoomOut/zoomBy)
  LatLng _lastCenter = const LatLng(0, 0);
  double _lastZoom = 14;

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

    _lastCenter = init.target;
    _lastZoom = init.zoom;

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

        // Map type
        await _c!.setMapType(_toMacType(p.mapType));

        // Seed layers
        await _syncMarkers(p.markers);
        await _syncPolylines(p.polylines);
        await _syncPolygons(p.polygons);
        await _syncCircles(p.circles);

        // Events
        _tapSub =
            _c!.onTap.listen((pt) => p.onTap?.call(LatLng(pt.lat, pt.lon)));
        _longSub = _c!.onLongPress
            .listen((pt) => p.onLongPress?.call(LatLng(pt.lat, pt.lon)));
        _annTapSub = _c!.onAnnotationTap.listen((id) {
          final m = _markers[id];
          m?.onTap?.call();
        });
        _regionSub = _c!.onRegionChanged.listen((e) {
          final center = LatLng(e.camera.target.lat, e.camera.target.lon);
          final zoom = _zoomFromDeltas(e.camera.latDelta, e.camera.lonDelta);
          _lastCenter = center;
          _lastZoom = zoom;

          p.onCameraMove?.call(
            CameraPosition(
              target: center,
              zoom: zoom,
              tilt: e.camera.pitch ?? 0.0,
              bearing: e.camera.heading ?? 0.0,
            ),
          );
          _idleDebounce?.cancel();
          _idleDebounce = Timer(const Duration(milliseconds: 180), () {
            p.onCameraIdle?.call();
          });
        });

        // Give a PlatformMapController back (wrapper over our platform controller)
        p.onMapCreated?.call(PlatformMapController(_MacController(_c!, this)));
      },
    );
  }

  @override
  void didUpdateWidget(covariant _MacContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_c == null) return;

    final prev = oldWidget.params;
    final next = widget.params;

    // Map options
    if (prev.mapType != next.mapType) {
      _c!.setMapType(_toMacType(next.mapType));
    }

    // Layers (diff and apply)
    _syncMarkers(next.markers);
    _syncPolylines(next.polylines);
    _syncPolygons(next.polygons);
    _syncCircles(next.circles);
  }

  // ---------------- Diffs & sync ----------------

  Future<void> _syncMarkers(Set<Marker> newSet) async {
    if (_c == null) return;
    final next = {for (final m in newSet) m.markerId.value: m};

    // removals
    for (final id
        in _markers.keys.where((k) => !next.containsKey(k)).toList()) {
      await _c!.removeAnnotation(id);
      _markers.remove(id);
    }

    // adds/updates (re-add if any meaningful change)
    for (final e in next.entries) {
      final id = e.key;
      final m = e.value;
      final old = _markers[id];

      final changed = old == null ||
          old.position != m.position ||
          (old.infoWindow.title != m.infoWindow.title) ||
          (old.infoWindow.snippet != m.infoWindow.snippet);

      if (changed) {
        if (old != null) await _c!.removeAnnotation(id);
        await _c!.addAnnotation(
          id: id,
          position: mac.LatLng(m.position.latitude, m.position.longitude),
          title: m.infoWindow.title,
          subtitle: m.infoWindow.snippet,
        );
        _markers[id] = m;
      }
    }
  }

  Future<void> _syncPolylines(Set<Polyline> newSet) async {
    if (_c == null) return;
    final next = {for (final p in newSet) p.polylineId.value: p};

    for (final id
        in _polylines.keys.where((k) => !next.containsKey(k)).toList()) {
      final overlayId = _polylineOverlayIds.remove(id);
      if (overlayId != null) await _c!.removeOverlay(overlayId);
      _polylines.remove(id);
    }

    for (final e in next.entries) {
      final id = e.key;
      final p = e.value;
      final old = _polylines[id];

      if (old == null || !_polylineEquals(old, p)) {
        final existing = _polylineOverlayIds.remove(id);
        if (existing != null) await _c!.removeOverlay(existing);

        final overlayId = await _c!.addPolyline(
          points: p.points
              .map((pt) => mac.LatLng(pt.latitude, pt.longitude))
              .toList(),
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

    for (final id
        in _polygons.keys.where((k) => !next.containsKey(k)).toList()) {
      final overlayId = _polygonOverlayIds.remove(id);
      if (overlayId != null) await _c!.removeOverlay(overlayId);
      _polygons.remove(id);
    }

    for (final e in next.entries) {
      final id = e.key;
      final p = e.value;
      final old = _polygons[id];

      if (old == null || !_polygonEquals(old, p)) {
        final existing = _polygonOverlayIds.remove(id);
        if (existing != null) await _c!.removeOverlay(existing);

        final overlayId = await _c!.addPolygon(
          points: p.points
              .map((pt) => mac.LatLng(pt.latitude, pt.longitude))
              .toList(),
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

    for (final id
        in _circles.keys.where((k) => !next.containsKey(k)).toList()) {
      final overlayId = _circleOverlayIds.remove(id);
      if (overlayId != null) await _c!.removeOverlay(overlayId);
      _circles.remove(id);
    }

    for (final e in next.entries) {
      final id = e.key;
      final c = e.value;
      final old = _circles[id];

      if (old == null || !_circleEquals(old, c)) {
        final existing = _circleOverlayIds.remove(id);
        if (existing != null) await _c!.removeOverlay(existing);

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
        return mac.MapType.standard;
    }
  }

  int _toArgb(Color c) {
    final r = (c.r * 255.0).round() & 0xff;
    final g = (c.g * 255.0).round() & 0xff;
    final b = (c.b * 255.0).round() & 0xff;
    final a = (c.a * 255.0).round() & 0xff;
    return r << 16 | g << 8 | b | (a << 24);
  }

  // crude zoom<->span heuristics; tweak for parity
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
      listEquals(a.points, b.points) &&
      a.color == b.color &&
      a.width == b.width;

  bool _polygonEquals(Polygon a, Polygon b) =>
      listEquals(a.points, b.points) &&
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
  Future<void> animateCamera(CameraUpdate cameraUpdate) =>
      _applyCameraUpdate(cameraUpdate, animated: true);

  @override
  Future<void> moveCamera(CameraUpdate cameraUpdate) =>
      _applyCameraUpdate(cameraUpdate, animated: false);

  Future<void> _applyCameraUpdate(CameraUpdate update,
      {required bool animated}) async {
    if (update is! _MacCameraUpdate) {
      // Unknown update (possibly from another implementation) – ignore safely.
      return;
    }

    switch (update.type) {
      case _MacCameraUpdateType.newCameraPosition:
        final cp = update.cameraPosition!;
        _state._lastCenter = cp.target;
        _state._lastZoom = cp.zoom;
        await _c.setCamera(
          mac.CameraPosition(
            target: mac.LatLng(cp.target.latitude, cp.target.longitude),
            latDelta: _state._deltaFromZoom(cp.zoom),
            lonDelta: _state._deltaFromZoom(cp.zoom),
            heading: cp.bearing,
            pitch: cp.tilt,
          ),
          animated: animated,
        );
        break;

      case _MacCameraUpdateType.newLatLng:
        final t = update.target!;
        _state._lastCenter = t;
        await _c.setCamera(
          mac.CameraPosition(target: mac.LatLng(t.latitude, t.longitude)),
          animated: animated,
        );
        break;

      case _MacCameraUpdateType.newLatLngZoom:
        final t = update.target!;
        final z = update.zoom!;
        _state._lastCenter = t;
        _state._lastZoom = z;
        await _c.setCamera(
          mac.CameraPosition(
            target: mac.LatLng(t.latitude, t.longitude),
            latDelta: _state._deltaFromZoom(z),
            lonDelta: _state._deltaFromZoom(z),
          ),
          animated: animated,
        );
        break;

      case _MacCameraUpdateType.newLatLngBounds:
        final b = update.bounds!;
        final pad = update.padding ?? 24.0;
        await _c.fitBounds(
          northEast: mac.LatLng(b.northeast.latitude, b.northeast.longitude),
          southWest: mac.LatLng(b.southwest.latitude, b.southwest.longitude),
          padding: pad,
          animated: animated,
        );
        _state._lastCenter = LatLng(
          (b.northeast.latitude + b.southwest.latitude) / 2,
          (b.northeast.longitude + b.southwest.longitude) / 2,
        );
        break;

      case _MacCameraUpdateType.zoomIn:
      case _MacCameraUpdateType.zoomOut:
      case _MacCameraUpdateType.zoomBy:
      case _MacCameraUpdateType.zoomTo:
        final base = _state._lastZoom;
        final newZoom = switch (update.type) {
          _MacCameraUpdateType.zoomIn => base + 1.0,
          _MacCameraUpdateType.zoomOut => base - 1.0,
          _MacCameraUpdateType.zoomBy => base + (update.amount ?? 0.0),
          _MacCameraUpdateType.zoomTo => update.zoom ?? base,
          _ => base,
        }
            .clamp(3.0, 20.0);
        _state._lastZoom = newZoom;
        await _c.setCamera(
          mac.CameraPosition(
            target: mac.LatLng(
                _state._lastCenter.latitude, _state._lastCenter.longitude),
            latDelta: _state._deltaFromZoom(newZoom),
            lonDelta: _state._deltaFromZoom(newZoom),
          ),
          animated: animated,
        );
        break;
    }
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async {
    // If your macOS plugin exposes getVisibleRegion later, forward it here.
    throw UnimplementedError('getVisibleRegion not supported on macOS yet.');
  }

  @override
  Future<void> showMarkerInfoWindow(MarkerId markerId) async {}

  @override
  Future<void> hideMarkerInfoWindow(MarkerId markerId) async {}

  @override
  Future<bool> isMarkerInfoWindowShown(MarkerId markerId) async => false;

  @override
  Future<Uint8List?> takeSnapshot() async =>
      null; // add real bytes if you expose snapshots
}

// ---------------- Platform factories (CameraUpdate & BitmapDescriptor) --------

class _MacPlatformCameraUpdate implements PlatformCameraUpdate {
  @override
  CameraUpdate newCameraPosition(CameraPosition cameraPosition) =>
      _MacCameraUpdate.newCameraPosition(cameraPosition);

  @override
  CameraUpdate newLatLng(LatLng latLng) => _MacCameraUpdate.newLatLng(latLng);

  @override
  CameraUpdate newLatLngZoom(LatLng latLng, double zoom) =>
      _MacCameraUpdate.newLatLngZoom(latLng, zoom);

  @override
  CameraUpdate newLatLngBounds(LatLngBounds bounds, double padding) =>
      _MacCameraUpdate.newLatLngBounds(bounds, padding);

  @override
  CameraUpdate zoomIn() => _MacCameraUpdate.zoomIn();

  @override
  CameraUpdate zoomOut() => _MacCameraUpdate.zoomOut();

  @override
  CameraUpdate zoomBy(double amount) => _MacCameraUpdate.zoomBy(amount);

  @override
  CameraUpdate zoomTo(double zoom) => _MacCameraUpdate.zoomTo(zoom);
}

enum _MacCameraUpdateType {
  newCameraPosition,
  newLatLng,
  newLatLngZoom,
  newLatLngBounds,
  zoomIn,
  zoomOut,
  zoomBy,
  zoomTo,
}

class _MacCameraUpdate extends CameraUpdate {
  _MacCameraUpdate._(
    this.type, {
    this.cameraPosition,
    this.target,
    this.bounds,
    this.padding,
    this.amount,
    this.zoom,
  });

  final _MacCameraUpdateType type;
  final CameraPosition? cameraPosition;
  final LatLng? target;
  final LatLngBounds? bounds;
  final double? padding;
  final double? amount;
  final double? zoom;

  factory _MacCameraUpdate.newCameraPosition(CameraPosition cp) =>
      _MacCameraUpdate._(_MacCameraUpdateType.newCameraPosition,
          cameraPosition: cp);

  factory _MacCameraUpdate.newLatLng(LatLng t) =>
      _MacCameraUpdate._(_MacCameraUpdateType.newLatLng, target: t);

  factory _MacCameraUpdate.newLatLngZoom(LatLng t, double z) =>
      _MacCameraUpdate._(_MacCameraUpdateType.newLatLngZoom,
          target: t, zoom: z);

  factory _MacCameraUpdate.newLatLngBounds(LatLngBounds b, double p) =>
      _MacCameraUpdate._(_MacCameraUpdateType.newLatLngBounds,
          bounds: b, padding: p);

  factory _MacCameraUpdate.zoomIn() =>
      _MacCameraUpdate._(_MacCameraUpdateType.zoomIn);

  factory _MacCameraUpdate.zoomOut() =>
      _MacCameraUpdate._(_MacCameraUpdateType.zoomOut);

  factory _MacCameraUpdate.zoomBy(double amount) =>
      _MacCameraUpdate._(_MacCameraUpdateType.zoomBy, amount: amount);

  factory _MacCameraUpdate.zoomTo(double zoom) =>
      _MacCameraUpdate._(_MacCameraUpdateType.zoomTo, zoom: zoom);
}

// BitmapDescriptor factory; expand later to support custom icons.
class _MacPlatformBitmapDescriptor implements PlatformBitmapDescriptor {
  @override
  Future<BitmapDescriptor> fromAssetImage(
    ImageConfiguration configuration,
    String assetName, {
    AssetBundle? bundle,
    String? package,
  }) async {
    return _MacBitmapDescriptor.asset(assetName, package: package);
  }

  @override
  BitmapDescriptor fromBytes(Uint8List byteData) {
    return _MacBitmapDescriptor.bytes(byteData);
  }
}

class _MacBitmapDescriptor extends BitmapDescriptor {
  _MacBitmapDescriptor._(this.assetName, this.bytes, {this.package});
  final String? assetName;
  final Uint8List? bytes;
  final String? package;

  factory _MacBitmapDescriptor.asset(String name, {String? package}) =>
      _MacBitmapDescriptor._(name, null, package: package);

  factory _MacBitmapDescriptor.bytes(Uint8List data) =>
      _MacBitmapDescriptor._(null, data);
}
