import 'package:flutter/foundation.dart';

/// Represents the most relevant weather values returned by the IDEAM service
/// for a particular station/municipality.
@immutable
class IdeamWeather {
  const IdeamWeather({
    required this.stationName,
    this.municipality,
    this.temperatureCelsius,
    this.feelsLikeCelsius,
    this.humidityPercentage,
    this.windSpeedMs,
    this.windDirection,
    this.pressureHpa,
    this.precipitationMm,
    this.observationTime,
  });

  /// Nombre de la estación reportado por el IDEAM.
  final String stationName;

  /// Municipio asociado al reporte, si está disponible.
  final String? municipality;

  /// Temperatura ambiente en °C.
  final double? temperatureCelsius;

  /// Sensación térmica (en °C) si la API la reporta.
  final double? feelsLikeCelsius;

  /// Humedad relativa en porcentaje (0-100).
  final double? humidityPercentage;

  /// Velocidad del viento en metros por segundo.
  final double? windSpeedMs;

  /// Dirección del viento en formato textual o grados.
  final String? windDirection;

  /// Presión atmosférica en hPa.
  final double? pressureHpa;

  /// Precipitación acumulada (mm) en el periodo informado.
  final double? precipitationMm;

  /// Momento de la observación.
  final DateTime? observationTime;

  /// Convierte una estructura JSON proporcionada por el servicio IDEAM en un
  /// objeto [IdeamWeather]. El servicio suele envolver los valores dentro de
  /// la clave `attributes`.
  factory IdeamWeather.fromFeature(Map<String, dynamic> feature) {
    final Map<String, dynamic> attributes = (feature['attributes'] as Map<String, dynamic>?) ?? feature;

    double? _asDouble(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value.replaceAll(',', '.'));
      }
      return null;
    }

    DateTime? _asDateTime(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is int) {
        // Algunos servicios ArcGIS retornan milisegundos desde la época Unix.
        try {
          return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
        } catch (_) {
          return null;
        }
      }
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    String _trimmed(dynamic value) {
      if (value == null) {
        return '';
      }
      return value.toString().trim();
    }

    final String stationName = _trimmed(
      attributes['nombre_estacion'] ?? attributes['NombreEstacion'] ?? attributes['station'] ?? attributes['name'],
    );
    final String municipality = _trimmed(
      attributes['municipio'] ?? attributes['Municipio'] ?? attributes['city'] ?? attributes['municipality'],
    );
    final String direction = _trimmed(
      attributes['direccion_viento'] ?? attributes['DireccionViento'] ?? attributes['wind_direction'],
    );

    return IdeamWeather(
      stationName: stationName.isEmpty ? 'Estación IDEAM' : stationName,
      municipality: municipality.isEmpty ? null : municipality,
      temperatureCelsius: _asDouble(attributes['temperatura'] ?? attributes['Temperatura'] ?? attributes['temp']),
      feelsLikeCelsius: _asDouble(attributes['sensacion'] ?? attributes['SensacionTermica'] ?? attributes['feels_like']),
      humidityPercentage: _asDouble(attributes['humedad'] ?? attributes['Humedad'] ?? attributes['humidity']),
      windSpeedMs: _asDouble(attributes['velocidad_viento'] ?? attributes['VelocidadViento'] ?? attributes['wind_speed']),
      windDirection: direction.isEmpty ? null : direction,
      pressureHpa: _asDouble(attributes['presion'] ?? attributes['Presion'] ?? attributes['pressure']),
      precipitationMm: _asDouble(attributes['precipitacion'] ?? attributes['Precipitacion'] ?? attributes['rain']),
      observationTime: _asDateTime(attributes['fecha_observacion'] ?? attributes['FechaObservacion'] ?? attributes['timestamp']),
    );
  }

  /// Velocidad del viento convertida a km/h.
  double? get windSpeedKmh {
    final double? speed = windSpeedMs;
    if (speed == null) {
      return null;
    }
    return speed * 3.6;
  }
}
