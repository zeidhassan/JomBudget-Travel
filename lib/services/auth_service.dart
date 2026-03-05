import 'package:uuid/uuid.dart';

import '../data/in_memory_repositories.dart';
import '../domain/models.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService(this._userRepository);

  final UserRepository _userRepository;
  final Uuid _uuid = const Uuid();

  AppUser login(String email, String password) {
    final user = _userRepository.findByEmail(email);
    if (user == null) {
      throw AuthException('No account found for $email');
    }
    if (!user.isActive) {
      throw AuthException('This account has been restricted by admin.');
    }
    if (user.password != password) {
      throw AuthException('Invalid password.');
    }
    return user;
  }

  AppUser register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      throw AuthException('Name, email, and password are required.');
    }
    final existing = _userRepository.findByEmail(email);
    if (existing != null) {
      throw AuthException('This email is already registered.');
    }

    final createdUser = AppUser(
      id: _uuid.v4(),
      name: name.trim(),
      email: email.trim().toLowerCase(),
      password: password,
      role: role,
    );
    return _userRepository.add(createdUser);
  }
}
