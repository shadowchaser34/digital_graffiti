import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider((ref) => AuthService());

final authInfoProvider = StateNotifierProvider<AuthInfoNotifier, AuthInfo?>(
  (ref) => AuthInfoNotifier(ref.read(authServiceProvider)),
);

class AuthInfoNotifier extends StateNotifier<AuthInfo?> {
  final AuthService _service;
  AuthInfoNotifier(this._service) : super(null) {
    state = _service.cachedAuthInfo;
    _init();
  }

  Future<void> _init() async {
    final info = await _service.signInAnonymously();
    state = info;
  }
}
