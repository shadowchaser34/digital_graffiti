import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import '../models/stroke.dart';
import '../models/sticker_model.dart';
import '../models/presence.dart';

class FirebaseService {
  final FirebaseFirestore? _fs = Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;
  final _uuid = const Uuid();
  final List<Stroke> _localStrokes = [];
  final List<StickerModel> _localStickers = [];
  final List<Presence> _localPresence = [];
  final StreamController<void> _strokeUpdates = StreamController<void>.broadcast();
  final StreamController<void> _stickerUpdates = StreamController<void>.broadcast();
  final StreamController<void> _presenceUpdates = StreamController<void>.broadcast();

  // Streams that yield Stroke and StickerModel lists
  Stream<List<Stroke>> strokesStream({required String posterId}) {
    final fs = _fs;
    if (fs == null) {
      return Stream<List<Stroke>>.multi((controller) {
        controller.add(List.unmodifiable(
          _localStrokes.where((stroke) => stroke.posterId == posterId),
        ));
        final sub = _strokeUpdates.stream.listen((_) {
          controller.add(List.unmodifiable(
            _localStrokes.where((stroke) => stroke.posterId == posterId),
          ));
        });
        controller.onCancel = sub.cancel;
      });
    }

    return fs.collection('strokes').where('posterId', isEqualTo: posterId).snapshots().map(
      (snap) {
        final strokes = snap.docs.map((d) => Stroke.fromMap(d.data())).toList();
        strokes.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return strokes;
      },
    );
  }

  Stream<List<StickerModel>> stickersStream({required String posterId}) {
    final fs = _fs;
    if (fs == null) {
      return Stream<List<StickerModel>>.multi((controller) {
        controller.add(List.unmodifiable(
          _localStickers.where((sticker) => sticker.posterId == posterId),
        ));
        final sub = _stickerUpdates.stream.listen((_) {
          controller.add(List.unmodifiable(
            _localStickers.where((sticker) => sticker.posterId == posterId),
          ));
        });
        controller.onCancel = sub.cancel;
      });
    }

    return fs.collection('stickers').where('posterId', isEqualTo: posterId).snapshots().map(
      (snap) {
        final stickers = snap.docs.map((d) => StickerModel.fromMap(d.data())).toList();
        stickers.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return stickers;
      },
    );
  }
  /// Set presence document for a single user.
  /// Presence documents are small and updated frequently.
  Future<void> setPresence(Presence p) async {
    final fs = _fs;
    if (fs == null) {
      _localPresence.removeWhere(
        (existing) => existing.userId == p.userId && existing.posterId == p.posterId,
      );
      _localPresence.add(p);
      _presenceUpdates.add(null);
      return;
    }

    final doc = fs.collection('presence').doc('${p.posterId}_${p.userId}');
    await doc.set(p.toMap());
  }

  /// Stream of presence documents for rendering indicators.
  Stream<List<Presence>> presenceStream({required String posterId}) {
    final fs = _fs;
    if (fs == null) {
      return Stream<List<Presence>>.multi((controller) {
        controller.add(List.unmodifiable(
          _localPresence.where((presence) => presence.posterId == posterId),
        ));
        final sub = _presenceUpdates.stream.listen((_) {
          controller.add(List.unmodifiable(
            _localPresence.where((presence) => presence.posterId == posterId),
          ));
        });
        controller.onCancel = sub.cancel;
      });
    }

    return fs.collection('presence').where('posterId', isEqualTo: posterId).snapshots().map(
      (snap) {
        final presence = snap.docs.map((d) => Presence.fromMap(d.data())).toList();
        presence.sort((a, b) => b.lastActive.compareTo(a.lastActive));
        return presence;
      },
    );
  }

  Future<void> addStroke(Stroke s) async {
    final fs = _fs;
    if (fs == null) {
      _localStrokes.removeWhere((existing) => existing.id == s.id);
      _localStrokes.add(s);
      _strokeUpdates.add(null);
      return;
    }

    final doc = fs.collection('strokes').doc(s.id);
    await doc.set(s.toMap());
  }

  /// Deletes a stroke document by id. Used for undo operations.
  Future<void> deleteStrokeById(String id) async {
    final fs = _fs;
    if (fs == null) {
      _localStrokes.removeWhere((existing) => existing.id == id);
      _strokeUpdates.add(null);
      return;
    }

    final doc = fs.collection('strokes').doc(id);
    await doc.delete();
  }

  Future<void> addSticker(StickerModel st) async {
    final fs = _fs;
    if (fs == null) {
      _localStickers.removeWhere((existing) => existing.id == st.id);
      _localStickers.add(st);
      _stickerUpdates.add(null);
      return;
    }

    final doc = fs.collection('stickers').doc(st.id);
    await doc.set(st.toMap());
  }

  // Per-user undo: delete latest stroke by user
  Future<void> undoLastStrokeByUser(String userId, {String posterId = 'default-poster'}) async {
    final fs = _fs;
    if (fs == null) {
      final index = _localStrokes.lastIndexWhere(
        (stroke) => stroke.userId == userId && stroke.posterId == posterId,
      );
      if (index >= 0) {
        _localStrokes.removeAt(index);
        _strokeUpdates.add(null);
      }
      return;
    }

    final q = await fs.collection('strokes').where('userId', isEqualTo: userId).where('posterId', isEqualTo: posterId).get();
    final docs = q.docs.toList()
      ..sort((a, b) {
        final at = (a.data()['timestamp'] as num).toInt();
        final bt = (b.data()['timestamp'] as num).toInt();
        return bt.compareTo(at);
      });
    if (docs.isNotEmpty) {
      await docs.first.reference.delete();
    }
  }

  String generateId() => _uuid.v4();
}
