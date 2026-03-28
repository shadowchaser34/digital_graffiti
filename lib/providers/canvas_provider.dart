import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../models/sticker_model.dart';
import '../models/presence.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';
import 'poster_provider.dart';

/// Provides a singleton [FirebaseService] instance to providers/widgets.
final firebaseServiceProvider = Provider((ref) => FirebaseService());

/// Main canvas state provider. Exposes strokes, stickers and presence in
/// real-time as they arrive from Firestore. Use the notifier to perform
/// actions such as adding strokes, stickers, or undo/redo.
final canvasProvider = StateNotifierProvider.family<CanvasNotifier, CanvasState, String>(
  (ref, posterId) {
    final svc = ref.read(firebaseServiceProvider);
    final auth = ref.read(authInfoProvider);
    return CanvasNotifier(svc, auth?.uid ?? 'anonymous', posterId);
  },
);

// Expose undo/redo availability
final canUndoProvider = Provider<bool>((ref) {
  final poster = ref.watch(activePosterProvider);
  return ref.watch(canvasProvider(poster.id)).canUndo;
});

final canRedoProvider = Provider<bool>((ref) {
  final poster = ref.watch(activePosterProvider);
  return ref.watch(canvasProvider(poster.id)).canRedo;
});

class CanvasState {
  final List<Stroke> strokes;
  final List<StickerModel> stickers;
  final List<Presence> presence;
  final bool canUndo;
  final bool canRedo;

  CanvasState({
    this.strokes = const [],
    this.stickers = const [],
    this.presence = const [],
    this.canUndo = false,
    this.canRedo = false,
  });

  CanvasState copyWith({
    List<Stroke>? strokes,
    List<StickerModel>? stickers,
    List<Presence>? presence,
    bool? canUndo,
    bool? canRedo,
  }) =>
      CanvasState(
        strokes: strokes ?? this.strokes,
        stickers: stickers ?? this.stickers,
        presence: presence ?? this.presence,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
      );
}

/// Handles local state and coordinates network updates.
///
/// Behavior:
/// - Subscribes to Firestore streams and keeps local state in `state`.
/// - Performs optimistic updates when adding strokes/stickers.
/// - Maintains per-user `_undoStack` / `_redoStack` for simple undo/redo.
class CanvasNotifier extends StateNotifier<CanvasState> {
  final FirebaseService _svc;
  final String _uid;
  final String _posterId;
  StreamSubscription<List<Stroke>>? _stSub;
  StreamSubscription<List<StickerModel>>? _stkrSub;
  StreamSubscription<List<Presence>>? _presenceSub;
  final List<Stroke> _undoStack = [];
  final List<Stroke> _redoStack = [];

  CanvasNotifier(this._svc, this._uid, this._posterId) : super(CanvasState()) {
    _stSub = _svc.strokesStream(posterId: _posterId).listen((list) {
      state = state.copyWith(strokes: list);
    });
    _stkrSub = _svc.stickersStream(posterId: _posterId).listen((list) {
      state = state.copyWith(stickers: list);
    });
    // subscribe to presence
    _presenceSub = _svc.presenceStream(posterId: _posterId).listen((list) {
      state = state.copyWith(presence: list);
    });
  }

  @override
  void dispose() {
    _stSub?.cancel();
    _stkrSub?.cancel();
    _presenceSub?.cancel();
    super.dispose();
  }

  Future<void> addStrokeLocalAndRemote(Stroke s) async {
    // local optimistic update
    state = state.copyWith(strokes: [...state.strokes, s]);
    // manage per-user undo stack
    if (s.userId == _uid) {
      _undoStack.add(s);
      _redoStack.clear();
      state = state.copyWith(canUndo: _undoStack.isNotEmpty, canRedo: _redoStack.isNotEmpty);
    }
    await _svc.addStroke(s);
  }

  Future<void> addSticker(StickerModel st) async {
    state = state.copyWith(stickers: [...state.stickers, st]);
    await _svc.addSticker(st);
  }

  Future<void> undoLast() async {
    // pop last stroke for this user from local undo stack
    if (_undoStack.isEmpty) return;
    final s = _undoStack.removeLast();
    _redoStack.add(s);
    // optimistic remove locally
    state = state.copyWith(
      strokes: state.strokes.where((st) => st.id != s.id).toList(),
      canUndo: _undoStack.isNotEmpty,
      canRedo: _redoStack.isNotEmpty,
    );
    // remove from server
    await _svc.deleteStrokeById(s.id);
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final s = _redoStack.removeLast();
    _undoStack.add(s);
    state = state.copyWith(strokes: [...state.strokes, s]);
    await _svc.addStroke(s);
    state = state.copyWith(canUndo: _undoStack.isNotEmpty, canRedo: _redoStack.isNotEmpty);
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<void> setPresence(double x, double y, bool isDrawing, int colorValue) async {
    final p = Presence(
      userId: _uid,
      posterId: _posterId,
      x: x,
      y: y,
      isDrawing: isDrawing,
      colorValue: colorValue,
      lastActive: DateTime.now().millisecondsSinceEpoch,
    );
    await _svc.setPresence(p);
  }
}
