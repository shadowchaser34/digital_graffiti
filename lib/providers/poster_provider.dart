import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/poster_anchor.dart';

final posterCatalogProvider = Provider<List<PosterAnchor>>((ref) => posterCatalog);

final activePosterProvider = StateProvider<PosterAnchor>((ref) => defaultPosterAnchor);
