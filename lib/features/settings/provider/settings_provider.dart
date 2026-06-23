import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that manages whether the viewfinder 3x3 grid lines are visible.
final gridLinesProvider = StateProvider<bool>((ref) => true);
