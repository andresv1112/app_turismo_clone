import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ideam_weather.dart';
import '../services/ideam_weather_service.dart';

class ParapenteDetailPage extends StatefulWidget {
  const ParapenteDetailPage({super.key});

  @override
  State<ParapenteDetailPage> createState() => _ParapenteDetailPageState();
}

class _ParapenteDetailPageState extends State<ParapenteDetailPage> {
  late final IdeamWeatherService _weatherService;
  late Future<IdeamWeather> _weatherFuture;
  Timer? _weatherTimer;
  bool _isAutoUpdating = false;

  @override
  void initState() {
    super.initState();
    _weatherService = IdeamWeatherService();
    _weatherFuture = _weatherService.fetchVillavicencioWeather();
    _weatherTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _refreshWeather(showUpdatingIndicator: true);
    });
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _weatherService.dispose();
    super.dispose();
  }

  Future<IdeamWeather> _refreshWeather({bool showUpdatingIndicator = false}) {
    final Future<IdeamWeather> newFuture =
        _weatherService.fetchVillavicencioWeather();
    setState(() {
      _weatherFuture = newFuture;
      if (showUpdatingIndicator) {
        _isAutoUpdating = true;
      }
    });

    if (showUpdatingIndicator) {
      newFuture.whenComplete(() {
        if (!mounted) {
          return;
        }
        setState(() {
          _isAutoUpdating = false;
        });
      });
    }

    return newFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Condiciones para Parapente'),
      ),
      body: FutureBuilder<IdeamWeather>(
        future: _weatherFuture,
        builder: (BuildContext context, AsyncSnapshot<IdeamWeather> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorView(
              error: snapshot.error,
              onRetry: () {
                _refreshWeather();
              },
            );
          }

          final IdeamWeather weather = snapshot.requireData;
          return Stack(
            children: <Widget>[
              RefreshIndicator(
                onRefresh: () async {
                  await _refreshWeather();
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _WeatherHeader(weather: weather),
                    const SizedBox(height: 16),
                    _WeatherValueTile(
                      icon: Icons.thermostat,
                      label: 'Temperatura',
                      value: weather.temperatureCelsius != null
                          ? '${weather.temperatureCelsius!.toStringAsFixed(1)} °C'
                          : 'No disponible',
                    ),
                    _WeatherValueTile(
                      icon: Icons.water_drop,
                      label: 'Humedad relativa',
                      value: weather.humidityPercentage != null
                          ? '${weather.humidityPercentage!.toStringAsFixed(0)} %'
                          : 'No disponible',
                    ),
                    _WeatherValueTile(
                      icon: Icons.air,
                      label: 'Velocidad del viento',
                      value: weather.windSpeedKmh != null
                          ? '${weather.windSpeedKmh!.toStringAsFixed(1)} km/h'
                          : 'No disponible',
                    ),
                    if (weather.windDirection != null)
                      _WeatherValueTile(
                        icon: Icons.explore,
                        label: 'Dirección del viento',
                        value: weather.windDirection!,
                      ),
                    _WeatherValueTile(
                      icon: Icons.speed,
                      label: 'Presión atmosférica',
                      value: weather.pressureHpa != null
                          ? '${weather.pressureHpa!.toStringAsFixed(0)} hPa'
                          : 'No disponible',
                    ),
                    _WeatherValueTile(
                      icon: Icons.grain,
                      label: 'Precipitación',
                      value: weather.precipitationMm != null
                          ? '${weather.precipitationMm!.toStringAsFixed(1)} mm'
                          : 'No disponible',
                    ),
                    if (weather.feelsLikeCelsius != null)
                      _WeatherValueTile(
                        icon: Icons.local_fire_department,
                        label: 'Sensación térmica',
                        value:
                            '${weather.feelsLikeCelsius!.toStringAsFixed(1)} °C',
                      ),
                  ],
                ),
              ),
              if (_isAutoUpdating)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WeatherHeader extends StatelessWidget {
  const _WeatherHeader({required this.weather});

  final IdeamWeather weather;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime? observation = weather.observationTime;
    final String subtitle;
    if (observation != null) {
      subtitle = 'Actualizado: ${TimeOfDay.fromDateTime(observation).format(context)}';
    } else {
      subtitle = 'Última actualización no disponible';
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              weather.stationName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              weather.municipality != null
                  ? '${weather.municipality}, Meta'
                  : 'Villavicencio, Meta',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherValueTile extends StatelessWidget {
  const _WeatherValueTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(value),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'No se pudo obtener la información meteorológica.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (error != null)
              Text(
                error.toString(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
