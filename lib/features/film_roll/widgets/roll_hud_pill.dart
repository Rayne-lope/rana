import 'package:flutter/material.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';

/// Compact, tappable exposure counter shown over the camera viewfinder.
class RollHudPill extends StatelessWidget {
  /// Creates the active Film Roll counter.
  const RollHudPill({
    required this.roll,
    required this.onTap,
    this.pendingExposures = 0,
    super.key,
  });

  /// The roll whose exposure count is displayed.
  final FilmRoll roll;

  /// Opens the active-roll controls.
  final VoidCallback onTap;

  /// Frames accepted by native capture which are still being saved.
  ///
  /// These consume capacity even though they are not yet durable exposures.
  final int pendingExposures;

  @override
  Widget build(BuildContext context) {
    final safePending = pendingExposures.clamp(0, roll.size.count);
    final capacityUsed = (roll.exposuresTaken + safePending).clamp(
      0,
      roll.size.count,
    );
    final capacityRemaining = (roll.size.count - capacityUsed).clamp(
      0,
      roll.size.count,
    );
    final fraction = capacityUsed / roll.size.count;
    final filledSegments = capacityUsed == 0
        ? 0
        : (fraction * _segmentCount).ceil().clamp(0, _segmentCount);
    final stateColor = _capacityColor(fraction);
    final capacityState = _capacityState(fraction);
    final counter = '${roll.exposuresTaken}/${roll.size.count}';
    final pendingLabel = safePending == 0
        ? null
        : '$safePending ${safePending == 1 ? 'frame' : 'frames'} processing';

    return Semantics(
      button: true,
      label:
          'Film Roll, $counter exposures used, '
          '$capacityRemaining frame capacity remaining'
          '${pendingLabel == null ? '' : ', $pendingLabel'}'
          ', $capacityState capacity',
      child: Tooltip(
        message: 'Film Roll: $counter',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            color: const Color(0xDE141416),
            child: InkWell(
              key: const ValueKey<String>('roll-hud-pill'),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        key: const ValueKey<String>('roll-hud-icon'),
                        Icons.local_movies_outlined,
                        color: stateColor,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List<Widget>.generate(
                          _segmentCount,
                          (index) => Container(
                            key: ValueKey<String>('roll-hud-segment-$index'),
                            width: 8,
                            height: 11,
                            margin: EdgeInsets.only(
                              right: index == _segmentCount - 1 ? 0 : 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: index < filledSegments
                                  ? stateColor
                                  : Colors.white.withValues(alpha: 0.12),
                              border: Border.all(
                                color: index < filledSegments
                                    ? stateColor.withValues(alpha: 0.7)
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        counter,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (pendingLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '+$safePending',
                          key: const ValueKey<String>('roll-hud-pending-count'),
                          style: const TextStyle(
                            color: Color(0xFFF4C44F),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const int _segmentCount = 5;

  Color _capacityColor(double fraction) {
    if (fraction >= 0.8) return const Color(0xFFE57373);
    if (fraction >= 0.5) return const Color(0xFFF4C44F);
    return const Color(0xFF81C784);
  }

  String _capacityState(double fraction) {
    if (fraction >= 0.8) return 'red';
    if (fraction >= 0.5) return 'amber';
    return 'green';
  }
}
