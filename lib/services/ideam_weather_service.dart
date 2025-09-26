import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/ideam_weather.dart';

/// Maneja las peticiones al servicio público del IDEAM para obtener las
/// condiciones meteorológicas más recientes de Villavicencio.
class IdeamWeatherService {
  IdeamWeatherService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  static const String _host = 'geoportal.ideam.gov.co';
  static const String _path =
      '/geoportal/rest/services/IDEAM/observacion_meteorologica/MapServer/0/query';
  static const String _municipality = 'VILLAVICENCIO';

  final http.Client _httpClient;

  /// Construye la URL de consulta para obtener la observación más reciente del
  /// municipio de Villavicencio.
  Uri _buildVillavicencioUrl() {
    return Uri.https(_host, _path, <String, String>{
      'f': 'json',
      'where': "Municipio='$_municipality'",
      'outFields': 'Municipio,NombreEstacion,Temperatura,VelocidadViento,DireccionViento,Humedad,Presion,Precipitacion,FechaObservacion',
      'orderByFields': 'FechaObservacion DESC',
      'resultRecordCount': '1',
    });
  }

  /// Obtiene el reporte meteorológico del IDEAM para Villavicencio.
  Future<IdeamWeather> fetchVillavicencioWeather() async {
    final Uri uri = _buildVillavicencioUrl();

    http.Response response;
    try {
      response = await _httpClient.get(uri);
    } on SocketException catch (error) {
      throw IdeamWeatherException('No fue posible conectarse con el IDEAM.', error);
    } on HttpException catch (error) {
      throw IdeamWeatherException('La solicitud al IDEAM falló.', error);
    } catch (error) {
      throw IdeamWeatherException('Ocurrió un error inesperado al consultar el IDEAM.', error);
    }

    if (response.statusCode != HttpStatus.ok) {
      throw IdeamWeatherException(
        'El IDEAM respondió con un estado inesperado (${response.statusCode}).',
        response.statusCode,
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error) {
      throw IdeamWeatherException('No fue posible leer la respuesta del IDEAM.', error);
    }

    final List<dynamic> features = (data['features'] as List<dynamic>?) ?? const <dynamic>[];
    if (features.isEmpty) {
      throw IdeamWeatherException('El IDEAM no retornó datos meteorológicos para Villavicencio.');
    }

    final Map<String, dynamic>? feature = features.first as Map<String, dynamic>?;
    if (feature == null || feature.isEmpty) {
      throw IdeamWeatherException('El formato del dato meteorológico recibido es inválido.');
    }

    return IdeamWeather.fromFeature(feature);
  }

  /// Libera los recursos del cliente HTTP.
  void dispose() {
    _httpClient.close();
  }
}

/// Error personalizado para las operaciones del servicio del IDEAM.
class IdeamWeatherException implements Exception {
  IdeamWeatherException(this.message, [this.detail]);

  final String message;
  final Object? detail;

  @override
  String toString() => 'IdeamWeatherException($message, detail: $detail)';
}
