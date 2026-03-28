import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/poster_catalog.dart';
import '../models/poster_pose.dart';

final posterCatalogProvider = Provider<List<PosterCatalogEntry>>((ref) => posterCatalog);

final activePosterIdProvider = StateProvider<String?>((ref) => posterCatalog.first.id);

final activePosterPoseProvider = StateProvider<PosterPose?>((ref) => null);