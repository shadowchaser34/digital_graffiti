import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../models/sticker_model.dart';
import '../models/presence.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

/// Provides a singleton [FirebaseService] instance to providers/widgets.
final firebaseServiceProvider = Provider((ref) => FirebaseService());

/// Main canvas state provider. Exposes strokes, stickers and presence in
/// real-time as they arrive from Firestore. Use the notifier to perform
/// actions such as adding strokes, stickers, or undo/redo.
final canvasProvider = StateNotifierProvider<CanvasNotifier, CanvasState>(
  (ref) {
    final svc = ref.read(firebaseServiceProvider);
    final auth = ref.read(authInfoProvider);
    return CanvasNotifier(svc, auth?.uid ?? 'anonymous');
  },
);

// Expose undo/redo availability
final canUndoProvider = Provider<bool>((ref) {
  final notifier = ref.read(canvasProvider.notifier);
  return notifier.canUndo;
});

final canRedoProvider = Provider<bool>((ref) {
  final notifier = ref.read(canvasProvider.notifier);
  return notifier.canRedo;
});

class CanvasState {
  final List<Stroke> strokes;
  final List<StickerModel> stickers;
  final List<Presence> presence;

  CanvasState({this.strokes = const [], this.stickers = const [], this.presence = const []});

  CanvasState copyWith({List<Stroke>? strokes, List<StickerModel>? stickers, List<Presence>? presence}) =>
      CanvasState(
        strokes: strokes ?? this.strokes,
        stickers: stickers ?? this.stickers,
        presence: presence ?? this.presence,
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
  StreamSubscription<List<Stroke>>? _stSub;
  StreamSubscription<List<StickerModel>>? _stkrSub;
  final List<Stroke> _undoStack = [];
  final List<Stroke> _redoStack = [];

  CanvasNotifier(this._svc, this._uid) : super(CanvasState()) {
    _stSub = _svc.strokesStream().listen((list) {
      state = state.copyWith(strokes: list);
    });
    _stkrSub = _svc.stickersStream().listen((list) {
      state = state.copyWith(stickers: list);
    });
    // subscribe to presence
    _svc.presenceStream().listen((list) {
      state = state.copyWith(presence: list);
    });
  }

  @override
  void dispose() {
    _stSub?.cancel();
    _stkrSub?.cancel();
    super.dispose();
  }

  Future<void> addStrokeLocalAndRemote(Stroke s) async {
    // local optimistic update
    state = state.copyWith(strokes: [...state.strokes, s]);
    // manage per-user undo stack
    if (s.userId == _uid) {
      _undoStack.add(s);
      _redoStack.clear();
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
        strokes: state.strokes.where((st) => st.id != s.id).toList());
    // remove from server
    await _svc.deleteStrokeById(s.id);
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final s = _redoStack.removeLast();
    _undoStack.add(s);
    state = state.copyWith(strokes: [...state.strokes, s]);
    await _svc.addStroke(s);
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<void> setPresence(double x, double y, bool isDrawing, int colorValue) async {
    final p = Presence(
      userId: _uid,
      x: x,
      y: y,
      isDrawing: isDrawing,
      colorValue: colorValue,
      lastActive: DateTime.now().millisecondsSinceEpoch,
    );
    await _svc.setPresence(p);
  }
}
