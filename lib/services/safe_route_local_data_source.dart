import '../models/safe_route.dart';
import 'local_storage_service.dart';

class SafeRouteLocalDataSource {
  SafeRouteLocalDataSource({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService.instance;

  final LocalStorageService _storage;

  Future<List<SafeRoute>> loadRoutes() => _storage.loadSafeRoutes();

  Future<void> saveRoutes(List<SafeRoute> routes) =>
      _storage.saveSafeRoutes(routes);
}