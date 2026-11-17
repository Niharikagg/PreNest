import 'package:prenest/core/contracts/security_service.dart';

// This mock must never ship.
class MockSecurityService implements SecurityService {
  bool _isUnlocked = true;

  @override
  Future<bool> authenticate() async => true;

  @override
  Future<List<int>> getDatabaseKey() async => List<int>.filled(32, 7);

  @override
  Future<void> lock() async {
    _isUnlocked = false;
  }

  @override
  bool get isUnlocked => _isUnlocked;
}
