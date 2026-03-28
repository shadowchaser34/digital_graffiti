import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lightweight auth wrapper used by the app.
///
/// Currently signs users in anonymously and assigns a deterministic color
/// based on their uid so strokes can be visually distinguished.
class AuthInfo {
  final String uid;
  final int colorValue;
  AuthInfo(this.uid, this.colorValue);
}

class AuthService {
  final FirebaseAuth? _auth = Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null;
  AuthInfo? _localAuthInfo;

  AuthInfo _buildAuthInfo(String uid) {
    final seed = uid.hashCode;
    final r = Random(seed);
    final colorValue = 0xFF000000 |
        ((r.nextInt(200) + 30) << 16) |
        ((r.nextInt(200) + 30) << 8) |
        (r.nextInt(200) + 30);
    return AuthInfo(uid, colorValue);
  }

  AuthInfo? get cachedAuthInfo {
    if (_auth != null) {
      return _localAuthInfo;
    }
    return _localAuthInfo ??= _buildAuthInfo('local-user');
  }

  /// Sign-in anonymously and return an [AuthInfo] with a deterministic
  /// color value derived from the uid.
  Future<AuthInfo> signInAnonymously() async {
    final auth = _auth;
    if (auth == null) {
      return _localAuthInfo ??= _buildAuthInfo('local-user');
    }

    try {
      final cred = await auth.signInAnonymously();
      final uid = cred.user!.uid;
      return _buildAuthInfo(uid);
    } catch (_) {
      return _localAuthInfo ??= _buildAuthInfo('local-user');
    }
  }

  String? get currentUid => _auth?.currentUser?.uid ?? _localAuthInfo?.uid;
}
