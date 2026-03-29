import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user.dart';

class AuthService {
  static const _usersKey = 'users';
  static const _lastUserIdKey = 'last_user_id';
  static const _pinPrefix = 'pin_';
  final FlutterSecureStorage _secureStorage;

  AuthService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<List<User>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_usersKey);
    if (data == null) return <User>[];
    try {
      return User.decodeList(data);
    } catch (_) {
      return <User>[];
    }
  }

  Future<void> _saveUsers(List<User> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, User.encodeList(users));
  }

  Future<List<User>> getAllUsers() => _loadUsers();

  Future<List<User>> getUsersByType(UserType type) async {
    final users = await _loadUsers();
    return users.where((u) => u.userType == type).toList();
  }

  Future<User?> getUserById(String id) async {
    final users = await _loadUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<User> createUser(User user, {String? pin}) async {
    final users = await _loadUsers();
    users.add(user);
    await _saveUsers(users);
    if (pin != null && pin.isNotEmpty) {
      await savePin(user.id, pin);
    }
    return user;
  }

  Future<User?> updateUser(User updated) async {
    final users = await _loadUsers();
    final index = users.indexWhere((u) => u.id == updated.id);
    if (index == -1) return null;
    users[index] = updated;
    await _saveUsers(users);
    return updated;
  }

  Future<void> deleteUser(String id) async {
    final users = await _loadUsers();
    users.removeWhere((u) => u.id == id);
    await _saveUsers(users);
    await _secureStorage.delete(key: '$_pinPrefix$id');
  }

  Future<void> savePin(String userId, String pin) async {
    if (pin.length != 4) {
      throw ArgumentError('PIN must be 4 digits');
    }
    await _secureStorage.write(key: '$_pinPrefix$userId', value: pin);
  }

  Future<bool> verifyPin(String userId, String pin) async {
    final stored = await _secureStorage.read(key: '$_pinPrefix$userId');
    if (stored == null) return false;
    return stored == pin;
  }

  Future<void> setLastLoggedUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUserIdKey, userId);
  }

  Future<String?> getLastLoggedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUserIdKey);
  }

  Future<void> clearLastLoggedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastUserIdKey);
  }

  Future<List<User>> getEmergencyContactsForUser(User user) async {
    final users = await _loadUsers();
    final contacts =
        users.where((u) => user.emergencyContactIds.contains(u.id)).toList();
    return contacts;
  }

  Future<List<User>> getDependentsForEmergencyContact(String contactId) async {
    final users = await _loadUsers();
    return users
        .where((u) => u.emergencyContactIds.contains(contactId))
        .toList();
  }
}
