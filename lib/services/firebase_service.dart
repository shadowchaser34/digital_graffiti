import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/stroke.dart';
import '../models/sticker_model.dart';
import '../models/presence.dart';

class FirebaseService {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Streams that yield Stroke and StickerModel lists
  Stream<List<Stroke>> strokesStream() {
    return _fs.collection('strokes').orderBy('timestamp').snapshots().map(
          (snap) => snap.docs
              .map((d) => Stroke.fromMap(d.data()))
              .toList(),
        );
  }

  Stream<List<StickerModel>> stickersStream() {
    return _fs.collection('stickers').orderBy('timestamp').snapshots().map(
          (snap) => snap.docs
              .map((d) => StickerModel.fromMap(d.data()))
              .toList(),
        );
  }
  /// Set presence document for a single user.
  /// Presence documents are small and updated frequently.
  Future<void> setPresence(Presence p) async {
    final doc = _fs.collection('presence').doc(p.userId);
    await doc.set(p.toMap());
  }

  /// Stream of presence documents for rendering indicators.
  Stream<List<Presence>> presenceStream() {
    return _fs.collection('presence').snapshots().map(
          (snap) => snap.docs
              .map((d) => Presence.fromMap(d.data()))
              .toList(),
        );
  }

  Future<void> addStroke(Stroke s) async {
    final doc = _fs.collection('strokes').doc(s.id);
    await doc.set(s.toMap());
  }

  /// Deletes a stroke document by id. Used for undo operations.
  Future<void> deleteStrokeById(String id) async {
    final doc = _fs.collection('strokes').doc(id);
    await doc.delete();
  }

  Future<void> addSticker(StickerModel st) async {
    final doc = _fs.collection('stickers').doc(st.id);
    await doc.set(st.toMap());
  }

  // Per-user undo: delete latest stroke by user
  Future<void> undoLastStrokeByUser(String userId) async {
    final q = await _fs
        .collection('strokes')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    for (final d in q.docs) {
      await d.reference.delete();
    }
  }

  String generateId() => _uuid.v4();
}
