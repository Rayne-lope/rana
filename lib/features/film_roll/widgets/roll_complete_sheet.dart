import 'package:flutter/material.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';

/// Acknowledgement shown once a roll saves its final exposure.
class RollCompleteSheet extends StatelessWidget {
  /// Creates the completed Film Roll acknowledgement.
  const RollCompleteSheet({
    required this.roll,
    required this.presetName,
    super.key,
  });

  /// Roll that just completed automatically.
  final FilmRoll roll;

  /// Display name of the recipe's preset.
  final String presetName;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) => Container(
        constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.92),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF17181C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.local_movies_rounded,
                color: Color(0xFFF4C44F),
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'ROLL COMPLETE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label:
                    '${roll.exposuresTaken}/${roll.size.count} frames saved with $presetName.',
                child: Text(
                  '${roll.exposuresTaken}/${roll.size.count} frames saved with '
                  '${presetName.toUpperCase()}.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey<String>('roll-complete-done-button'),
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFFF4C44F),
                  foregroundColor: const Color(0xFF181818),
                ),
                child: const Text(
                  'DONE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
