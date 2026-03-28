import 'dart:math';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign-in anonymously and return an [AuthInfo] with a deterministic
  /// color value derived from the uid.
  Future<AuthInfo> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    final uid = cred.user!.uid;
    // Generate a pleasant-looking color from uid hash.
    final seed = uid.hashCode;
    final r = Random(seed);
    final colorValue = 0xFF000000 |
        ((r.nextInt(200) + 30) << 16) |
        ((r.nextInt(200) + 30) << 8) |
        (r.nextInt(200) + 30);
    return AuthInfo(uid, colorValue);
  }

  String? get currentUid => _auth.currentUser?.uid;
}
