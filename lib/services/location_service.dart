import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationState {
  const LocationState({
    this.isLoading = false,
    this.position,
    this.errorMessage,
  });

  final bool isLoading;
  final Position? position;
  final String? errorMessage;

  bool get hasLocation => position != null;
  bool get hasError => errorMessage != null;

  LocationState copyWith({
    bool? isLoading,
    Position? position,
    bool resetPosition = false,
    String? errorMessage,
    bool resetError = false,
  }) {
    return LocationState(
      isLoading: isLoading ?? this.isLoading,
      position: resetPosition ? null : (position ?? this.position),
      errorMessage: resetError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  final ValueNotifier<LocationState> _stateNotifier =
      ValueNotifier<LocationState>(const LocationState());

  StreamSubscription<Position>? _positionSubscription;
  bool _isInitializing = false;

  LocationState get state => _stateNotifier.value;

  ValueListenable<LocationState> get stateListenable => _stateNotifier;

  Future<void> initialize() async {
    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    _stateNotifier.value =
        _stateNotifier.value.copyWith(isLoading: true, resetError: true);

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _stateNotifier.value = const LocationState(
          isLoading: false,
          position: null,
          errorMessage:
              'Activa los servicios de ubicación para ver tu posición en tiempo real.',
        );
        return;
      }

      PermissionStatus permissionStatus =
          await Permission.locationWhenInUse.status;

      if (permissionStatus.isDenied || permissionStatus.isRestricted) {
        permissionStatus = await Permission.locationWhenInUse.request();
      }

      if (permissionStatus.isPermanentlyDenied) {
        _stateNotifier.value = const LocationState(
          isLoading: false,
          position: null,
          errorMessage:
              'Ve a la configuración del dispositivo y otorga permisos de ubicación.',
        );
        return;
      }

      if (!permissionStatus.isGranted) {
        _stateNotifier.value = const LocationState(
          isLoading: false,
          position: null,
          errorMessage:
              'Los permisos de ubicación son necesarios para mostrar tu posición.',
        );
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      _stateNotifier.value = LocationState(
        isLoading: false,
        position: position,
        errorMessage: null,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
      ).listen(
        (Position update) {
          _stateNotifier.value = LocationState(
            isLoading: false,
            position: update,
            errorMessage: null,
          );
        },
        onError: (Object error) {
          _stateNotifier.value = LocationState(
            isLoading: false,
            position: null,
            errorMessage:
                'Ocurrió un problema al obtener tu ubicación: $error',
          );
        },
      );
    } on PermissionDeniedException {
      _stateNotifier.value = const LocationState(
        isLoading: false,
        position: null,
        errorMessage:
            'No se pudo acceder a la ubicación. Revisa los permisos concedidos.',
      );
    } catch (error) {
      _stateNotifier.value = LocationState(
        isLoading: false,
        position: null,
        errorMessage:
            'Ocurrió un problema al obtener tu ubicación: $error',
      );
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> refresh() => initialize();

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}