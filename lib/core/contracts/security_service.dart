// FROZEN: changes need approval from every team member
abstract class SecurityService {
  Future<bool> authenticate();

  // 32 random bytes created once, never logged.
  Future<List<int>> getDatabaseKey();

  Future<void> lock();

  bool get isUnlocked;
}
