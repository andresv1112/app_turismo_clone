import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'models/report.dart';
import 'models/safe_route.dart';
import 'models/user_preferences.dart';
import 'services/local_storage_service.dart';
import 'services/location_service.dart';
import 'services/safe_route_local_data_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Turismo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  late final List<Widget> _tabPages;
  late final List<BottomNavigationBarItem> _navigationItems;
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();

  static const List<_NavigationTab> _tabs = <_NavigationTab>[
    _NavigationTab(
      label: 'Mapa',
      icon: Icons.map,
      page: MapaPage(
        key: PageStorageKey<String>('MapaPage'),
      ),
    ),
    _NavigationTab(
      label: 'Rutas Seguras',
      icon: Icons.route,
      page: RutasSegurasPage(
        key: PageStorageKey<String>('RutasSegurasPage'),
      ),
    ),
    _NavigationTab(
      label: 'Reportes',
      icon: Icons.report,
      page: ReportesPage(
        key: PageStorageKey<String>('ReportesPage'),
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabPages =
        _tabs.map((tab) => tab.page).toList(growable: false);
    _navigationItems = _tabs
        .map(
          (tab) => BottomNavigationBarItem(
            icon: Icon(tab.icon),
            label: tab.label,
          ),
        )
        .toList(growable: false);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _NavigationTab currentTab = _tabs[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(currentTab.label),
      ),
      body: PageStorage(
        bucket: _pageStorageBucket,
        child: IndexedStack(
          index: _selectedIndex,
          children: _tabPages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: _navigationItems,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class _NavigationTab {
  const _NavigationTab({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}

class DangerZone {
  const DangerZone({
    required this.id,
    required this.center,
    required this.title,
    required this.description,
    required this.specificDangers,
    required this.securityRecommendations,
    this.radius = defaultRadius,
  });

  static const double defaultRadius = 100;

  final String id;
  final LatLng center;
  final String title;
  final String description;
  final String specificDangers;
  final String securityRecommendations;
  final double radius;
}

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  static const List<DangerZone> _dangerZones = [
    DangerZone(
      id: 'centro_historico_villavicencio',
      center: LatLng(4.1161999958575795, -73.6088337333233),
      title: 'Centro histórico de Villavicencio',
      description:
          'Corredor comercial y peatonal con alta afluencia de visitantes, entidades financieras y comercio informal.',
      specificDangers:
          'Se reportan hurtos menores a transeúntes, motociclistas que irrumpen en las zonas peatonales y acumulación de puestos ambulantes que obstaculizan los puntos de evacuación al final de la tarde.',
      securityRecommendations:
          'Mantén tus objetos de valor seguros, evita manipular dinero en vía pública, recorre rutas iluminadas después del anochecer y coordina puntos de encuentro en lugares vigilados.',
      radius: DangerZone.defaultRadius,
    ),
    DangerZone(
      id: 'terminal_transporte_villavicencio',
      center: LatLng(4.110716544734726, -73.62999691007467),
      title: 'Terminal de Transporte de Villavicencio',
      description:
          'Nodo de conexión intermunicipal con flujo constante de pasajeros, vendedores informales y parqueaderos improvisados.',
      specificDangers:
          'Ocurren robos de equipaje durante el abordaje, ofertas de transporte no autorizado y maniobras continuas de buses y camiones en las bahías de espera.',
      securityRecommendations:
          'Compra tus tiquetes únicamente en puntos oficiales, permanece en áreas iluminadas mientras esperas, vigila tu equipaje en todo momento y utiliza servicios de transporte autorizados para tus desplazamientos.',
      radius: DangerZone.defaultRadius,
    ),
  ];

  final LocationService _locationService = LocationService.instance;
  late final VoidCallback _locationListener;
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Marker? _userMarker;
  bool _isLoading = true;
  String? _errorMessage;
  String? _activeZoneId;
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    _locationListener = () {
      _handleLocationUpdate(_locationService.state);
    };

    final LocationState initialState = _locationService.state;
    _isLoading = initialState.isLoading;
    _errorMessage = initialState.errorMessage;
    _currentPosition = initialState.position;
    _userMarker = initialState.position != null
        ? _buildUserMarker(initialState.position!)
        : null;

    final Position? initialPosition = initialState.position;
    if (initialPosition != null) {
      unawaited(_moveCameraToPosition(initialPosition));
      unawaited(_evaluateDangerZones(initialPosition));
    }

    _locationService.stateListenable.addListener(_locationListener);
    unawaited(_locationService.initialize());
  }

  @override
  void dispose() {
    _locationService.stateListenable.removeListener(_locationListener);
    _mapController?.dispose();
    super.dispose();
  }

  void _handleLocationUpdate(LocationState state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = state.isLoading;
      _errorMessage = state.errorMessage;
      _currentPosition = state.position;
      _userMarker = state.position != null
          ? _buildUserMarker(state.position!)
          : null;
    });

    final Position? position = state.position;
    if (position != null) {
      unawaited(_moveCameraToPosition(position));
      unawaited(_evaluateDangerZones(position));
    }
  }

  Future<void> _requestLocationRefresh() => _locationService.refresh();

  Future<void> _moveCameraToPosition(Position position) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    final target = LatLng(position.latitude, position.longitude);
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 17),
      ),
    );
  }

  Marker _buildUserMarker(Position position) {
    return Marker(
      markerId: const MarkerId('user_location'),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: const InfoWindow(title: 'Tu ubicación'),
    );
  }

  Future<void> _evaluateDangerZones(Position position) async {
    final zone = _findDangerZone(position);

    if (zone == null) {
      if (_activeZoneId != null && mounted) {
        setState(() {
          _activeZoneId = null;
        });
      }
      return;
    }

    if (_activeZoneId == zone.id) {
      return;
    }

    if (mounted) {
      setState(() {
        _activeZoneId = zone.id;
      });
    } else {
      _activeZoneId = zone.id;
    }

    await _showDangerDialog(zone);
  }

  DangerZone? _findDangerZone(Position position) {
    for (final zone in _dangerZones) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );

      if (distance <= zone.radius) {
        return zone;
      }
    }
    return null;
  }

  Future<void> _showDangerDialog(DangerZone zone) async {
    if (_isShowingDialog || !mounted) {
      return;
    }

    _isShowingDialog = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('⚠️ Zona de Precaución'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(zone.description),
                const SizedBox(height: 12),
                Text(
                  'Peligros específicos del área',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(zone.specificDangers),
                const SizedBox(height: 12),
                Text(
                  'Recomendaciones de seguridad',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(zone.securityRecommendations),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Entendido'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isShowingDialog = false;
        });
      } else {
        _isShowingDialog = false;
      }
    }
  }

  Set<Circle> get _dangerZoneCircles {
    return _dangerZones
        .map(
          (zone) => Circle(
            circleId: CircleId(zone.id),
            center: zone.center,
            radius: zone.radius,
            fillColor: Colors.red.withOpacity(0.2),
            strokeColor: Colors.red.withOpacity(0.5),
            strokeWidth: 2,
          ),
        )
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_errorMessage != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => unawaited(_requestLocationRefresh()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    } else {
      final initialTarget = _currentPosition != null
          ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
          : _dangerZones.first.center;

      body = GoogleMap(
        initialCameraPosition: CameraPosition(target: initialTarget, zoom: 16),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        compassEnabled: true,
        circles: _dangerZoneCircles,
        markers: {
          if (_userMarker != null) _userMarker!,
        },
        onMapCreated: (controller) {
          _mapController = controller;
          final position = _currentPosition;
          if (position != null) {
            _moveCameraToPosition(position);
          }
        },
      );
    }

    return body;
  }
}

class RutasSegurasPage extends StatefulWidget {
  const RutasSegurasPage({super.key});

  @override
  State<RutasSegurasPage> createState() => _RutasSegurasPageState();
}

class _RutasSegurasPageState extends State<RutasSegurasPage> {
  static const List<SafeRoute> _defaultRoutes = <SafeRoute>[
    SafeRoute(
      name: 'Vereda Buenavista',
      duration: 'A 15 minutos de Villavicencio',
      difficulty: 'Actividades para todos',
      description:
          '🍃 La vereda Buenavista ofrece un clima distinto en Villavicencio, a tan solo '
          '15 minutos de su casco urbano, ideal para el turismo deportivo, de naturaleza '
          'y religioso.',
      pointsOfInterest: <String>[
        'Miradores',
        'Parapente',
        'Caminata ecológica',
      ],
    ),
  ];

  static const LatLng _veredaBuenavistaLocation =
      LatLng(4.157296670026874, -73.68158509824853);

  final SafeRouteLocalDataSource _localDataSource = SafeRouteLocalDataSource();
  List<SafeRoute> _routes = const <SafeRoute>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRoutes();
  }

  Future<void> _initializeRoutes() async {
    await _localDataSource.saveRoutes(_defaultRoutes);

    if (!mounted) {
      return;
    }

    setState(() {
      _routes = _defaultRoutes;
      _isLoading = false;
    });
  }

  Future<void> _openRouteOnMap(SafeRoute route) async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SafeRouteMapView(
          routeName: route.name,
          target: _veredaBuenavistaLocation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final ThemeData theme = Theme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _routes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (BuildContext context, int index) {
        final SafeRoute route = _routes[index];

        return Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  route.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _RouteInfo(icon: Icons.schedule, label: route.duration),
                    _RouteInfo(icon: Icons.terrain, label: route.difficulty),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  route.description,
                  style: theme.textTheme.bodyMedium,
                ),
                if (route.pointsOfInterest.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Puntos de interés',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: route.pointsOfInterest
                        .map((String point) => Chip(label: Text(point)))
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _openRouteOnMap(route),
                    icon: const Icon(Icons.map),
                    label: const Text('Ver en Mapa'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RouteInfo extends StatelessWidget {
  const _RouteInfo({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class SafeRouteMapView extends StatelessWidget {
  const SafeRouteMapView({
    super.key,
    required this.routeName,
    required this.target,
  });

  final String routeName;
  final LatLng target;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(routeName),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: target, zoom: 16),
        markers: <Marker>{
          Marker(
            markerId: MarkerId(routeName),
            position: target,
            infoWindow: InfoWindow(title: routeName),
          ),
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
      ),
    );
  }
}

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final LocalStorageService _storageService = LocalStorageService.instance;
  final LocationService _locationService = LocationService.instance;

  late final VoidCallback _preferencesListener;
  late final VoidCallback _locationListener;

  ReportType? _selectedType;
  bool _shareLocation = true;
  bool _isSubmitting = false;
  LocationState _locationState = const LocationState();

  @override
  void initState() {
    super.initState();

    final UserPreferences initialPreferences = _storageService.preferences;
    final String? preferredTypeId = initialPreferences.preferredReportTypeId;
    if (preferredTypeId != null && preferredTypeId.isNotEmpty) {
      _selectedType = ReportType.fromId(preferredTypeId);
    }
    _shareLocation = initialPreferences.shareLocation;
    _locationState = _locationService.state;

    _preferencesListener = () {
      if (!mounted) {
        return;
      }

      final UserPreferences prefs = _storageService.preferences;
      setState(() {
        _shareLocation = prefs.shareLocation;
        final String? storedTypeId = prefs.preferredReportTypeId;
        if (storedTypeId != null && storedTypeId.isNotEmpty) {
          _selectedType = ReportType.fromId(storedTypeId);
        }
      });
    };

    _locationListener = () {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationState = _locationService.state;
      });
    };

    _storageService.preferencesListenable.addListener(_preferencesListener);
    _locationService.stateListenable.addListener(_locationListener);
    unawaited(_locationService.initialize());
  }

  @override
  void dispose() {
    _storageService.preferencesListenable.removeListener(_preferencesListener);
    _locationService.stateListenable.removeListener(_locationListener);
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildForm(context),
          const SizedBox(height: 24),
          ValueListenableBuilder<List<Report>>(
            valueListenable: _storageService.reportsListenable,
            builder: (BuildContext context, List<Report> reports, _) {
              return _buildReportsSection(context, reports);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Nuevo reporte',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReportType>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Tipo de reporte',
              border: OutlineInputBorder(),
            ),
            validator: (ReportType? value) {
              if (value == null) {
                return 'Selecciona el tipo de reporte';
              }
              return null;
            },
            items: ReportType.values
                .map(
                  (ReportType type) => DropdownMenuItem<ReportType>(
                    value: type,
                    child: Text(type.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (ReportType? value) {
              setState(() {
                _selectedType = value;
              });

              if (value != null) {
                final UserPreferences currentPreferences =
                    _storageService.preferences.copyWith(
                  preferredReportTypeId: value.id,
                );
                unawaited(
                  _storageService.saveUserPreferences(currentPreferences),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Describe lo ocurrido',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (String? value) {
              if (value == null || value.trim().isEmpty) {
                return 'La descripción es obligatoria';
              }

              if (value.trim().length < 10) {
                return 'Describe lo sucedido con al menos 10 caracteres';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildLocationIndicator(context),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Compartir ubicación en mis reportes'),
            subtitle: Text(
              _shareLocation
                  ? 'La latitud y longitud se guardarán junto al reporte.'
                  : 'Solo se almacenará el texto del reporte.',
            ),
            value: _shareLocation,
            onChanged: (bool value) {
              setState(() {
                _shareLocation = value;
              });

              final UserPreferences currentPreferences =
                  _storageService.preferences.copyWith(
                shareLocation: value,
              );
              unawaited(
                _storageService.saveUserPreferences(currentPreferences),
              );
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _handleSubmit,
              icon: const Icon(Icons.send),
              label: Text(_isSubmitting ? 'Enviando...' : 'Enviar Reporte'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationIndicator(BuildContext context) {
    final LocationState state = _locationState;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color iconColor;
    Widget message;
    Widget? trailing;

    if (state.isLoading) {
      icon = Icons.my_location;
      iconColor = colorScheme.primary;
      message = const Text('Obteniendo ubicación actual...');
      trailing = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (state.errorMessage != null) {
      icon = Icons.location_off_outlined;
      iconColor = colorScheme.error;
      message = Text(state.errorMessage!);
    } else if (state.position != null) {
      final Position position = state.position!;
      icon = Icons.place_outlined;
      iconColor = colorScheme.primary;
      final String coordinates =
          'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}';
      message = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(coordinates),
          const SizedBox(height: 4),
          Text(
            _shareLocation
                ? 'La ubicación se incluirá en el reporte.'
                : 'Has elegido no compartir la ubicación en este reporte.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    } else {
      icon = Icons.location_searching;
      iconColor = colorScheme.secondary;
      message = const Text('Ubicación no disponible en este momento.');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: message),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildReportsSection(BuildContext context, List<Report> reports) {
    final ThemeData theme = Theme.of(context);

    if (reports.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Reportes guardados',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Aún no has registrado reportes. Completa el formulario para guardar el primero.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Reportes guardados',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...List<Widget>.generate(reports.length, (int index) {
          final Report report = reports[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index == reports.length - 1 ? 0 : 12),
            child: _buildReportCard(context, report),
          );
        }),
      ],
    );
  }

  Widget _buildReportCard(BuildContext context, Report report) {
    final ThemeData theme = Theme.of(context);
    final ReportType type = ReportType.fromId(report.typeId);
    final String formattedDate = _formatDate(report.createdAt);
    final bool hasLocation =
        report.latitude != null && report.longitude != null;
    final String locationText = hasLocation
        ? 'Lat: ${report.latitude!.toStringAsFixed(4)}, Lng: ${report.longitude!.toStringAsFixed(4)}'
        : 'Este reporte se guardó sin coordenadas.';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        type.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar reporte',
                  onPressed: () => unawaited(_removeReport(report)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: hasLocation
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationText,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_isSubmitting) {
      return;
    }
    unawaited(_submitReport());
  }

  Future<void> _submitReport() async {
    final FormState? formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final ReportType? selectedType = _selectedType;
    if (selectedType == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    FocusScope.of(context).unfocus();

    final Position? position = _locationState.position;
    final double? latitude =
        _shareLocation && position != null ? position.latitude : null;
    final double? longitude =
        _shareLocation && position != null ? position.longitude : null;

    try {
      await _storageService.saveReport(
        type: selectedType,
        description: _descriptionController.text.trim(),
        latitude: latitude,
        longitude: longitude,
      );

      final UserPreferences updatedPreferences =
          _storageService.preferences.copyWith(
        preferredReportTypeId: selectedType.id,
        shareLocation: _shareLocation,
      );
      await _storageService.saveUserPreferences(updatedPreferences);

      if (!mounted) {
        return;
      }

      _descriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte guardado en el dispositivo.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar el reporte: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      } else {
        _isSubmitting = false;
      }
    }
  }

  Future<void> _removeReport(Report report) async {
    try {
      await _storageService.deleteReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte eliminado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar el reporte: $error'),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String year = local.year.toString();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}