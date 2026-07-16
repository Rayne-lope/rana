import 'package:flutter/material.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';

/// Bottom sheet with the active roll's locked recipe and lifecycle actions.
class RollInfoSheet extends StatefulWidget {
  /// Creates the active Film Roll information sheet.
  const RollInfoSheet({
    required this.roll,
    required this.presetName,
    required this.aspectRatioLabel,
    required this.pendingExposures,
    required this.onEnd,
    required this.onAbandon,
    super.key,
  });

  /// Active roll displayed by this sheet.
  final FilmRoll roll;

  /// Display name of the locked preset.
  final String presetName;

  /// Display label of the locked aspect ratio.
  final String aspectRatioLabel;

  /// Native captures that must complete before lifecycle actions are safe.
  final int pendingExposures;

  /// Archives the active roll as completed.
  final Future<bool> Function() onEnd;

  /// Deletes only the roll grouping.
  final Future<bool> Function() onAbandon;

  @override
  State<RollInfoSheet> createState() => _RollInfoSheetState();
}

class _RollInfoSheetState extends State<RollInfoSheet> {
  bool _isSubmitting = false;

  bool get _canChangeLifecycle =>
      widget.pendingExposures == 0 && !_isSubmitting;

  Future<void> _endRoll() async {
    if (!_canChangeLifecycle) return;
    if (!widget.roll.isFull) {
      final confirmed = await _confirm(
        title: 'END ROLL?',
        body:
            '${widget.roll.remainingExposures} frames will stay unused. '
            'This roll will be archived in your Rolls history.',
        confirmLabel: 'END ROLL',
        confirmColor: const Color(0xFFF4C44F),
      );
      if (confirmed != true || !mounted) return;
    }
    await _submit(widget.onEnd);
  }

  Future<void> _abandonRoll() async {
    if (!_canChangeLifecycle) return;
    final confirmed = await _confirm(
      title: 'ABANDON ROLL?',
      body:
          'This removes the Film Roll grouping. Already saved photos stay '
          'available in Photos.',
      confirmLabel: 'ABANDON ROLL',
      confirmColor: const Color(0xFFE57373),
    );
    if (confirmed != true || !mounted) return;
    await _submit(widget.onAbandon);
  }

  Future<void> _submit(Future<bool> Function() action) async {
    setState(() => _isSubmitting = true);
    final succeeded = await action();
    if (!mounted) return;
    if (succeeded) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSubmitting = false);
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1B1C20),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      content: Text(body, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: const Color(0xFF181818),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final processing = widget.pendingExposures > 0;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF17181C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'FILM ROLL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 18),
            _InfoRow(label: 'PRESET', value: widget.presetName.toUpperCase()),
            _InfoRow(label: 'FORMAT', value: widget.aspectRatioLabel),
            _InfoRow(
              label: 'EXPOSURES',
              value: '${widget.roll.exposuresTaken}/${widget.roll.size.count}',
            ),
            _InfoRow(
              label: 'REMAINING',
              value: '${widget.roll.remainingExposures}',
            ),
            if (processing) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4C44F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF4C44F).withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'PROCESSING ${widget.pendingExposures} '
                  '${widget.pendingExposures == 1 ? 'FRAME' : 'FRAMES'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF4C44F),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey<String>('end-roll-button'),
              onPressed: _canChangeLifecycle ? _endRoll : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFFF4C44F),
                foregroundColor: const Color(0xFF181818),
              ),
              child: Text(
                _isSubmitting ? 'SAVING…' : 'END ROLL',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey<String>('abandon-roll-button'),
              onPressed: _canChangeLifecycle ? _abandonRoll : null,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: const Color(0xFFE57373),
              ),
              child: const Text(
                'ABANDON ROLL',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );
}
