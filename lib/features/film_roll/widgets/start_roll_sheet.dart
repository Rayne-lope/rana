import 'package:flutter/material.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/film_roll_lifecycle.dart';

/// Bottom sheet for loading a Film Roll with the current locked recipe.
class StartRollSheet extends StatefulWidget {
  /// Creates the Film Roll loading sheet.
  const StartRollSheet({
    required this.presetName,
    required this.aspectRatioLabel,
    required this.onLoad,
    this.initialSize = FilmRollSize.twentyFour,
    super.key,
  });

  /// Preset that will be locked into the new roll.
  final String presetName;

  /// Aspect ratio that will be locked into the new roll.
  final String aspectRatioLabel;

  /// Creates the roll with the selected exposure count.
  final Future<FilmRollActionResult> Function(FilmRollSize size) onLoad;

  /// Pre-selected number of exposures.
  final FilmRollSize initialSize;

  @override
  State<StartRollSheet> createState() => _StartRollSheetState();
}

class _StartRollSheetState extends State<StartRollSheet> {
  late FilmRollSize _selectedSize = widget.initialSize;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loadRoll() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onLoad(_selectedSize);
      if (!mounted) return;
      if (result.succeeded) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            result.message ??
            'Could not load this Film Roll. Check the recipe and try again.';
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load this Film Roll. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: PopScope(
      canPop: !_isLoading,
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.92),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF17181C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const ValueKey<String>('start-roll-close-button'),
                      tooltip: 'Close',
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'LOAD FILM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.2,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your current recipe stays locked until this roll is finished.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                _LockedRecipeRow(
                  label: 'PRESET',
                  value: widget.presetName.toUpperCase(),
                ),
                const SizedBox(height: 8),
                _LockedRecipeRow(
                  label: 'FORMAT',
                  value: widget.aspectRatioLabel,
                ),
                const SizedBox(height: 22),
                const Text(
                  'EXPOSURES',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: FilmRollSize.values
                      .map(
                        (size) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: size == FilmRollSize.thirtySix ? 0 : 8,
                            ),
                            child: _SizeButton(
                              size: size,
                              isSelected: size == _selectedSize,
                              onTap: _isLoading
                                  ? null
                                  : () => setState(() => _selectedSize = size),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _errorMessage!,
                      key: const ValueKey<String>('start-roll-error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE57373),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const ValueKey<String>('load-roll-button'),
                  onPressed: _isLoading ? null : _loadRoll,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFFF4C44F),
                    foregroundColor: const Color(0xFF161616),
                  ),
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_movies_outlined),
                  label: Text(
                    _isLoading
                        ? 'LOADING…'
                        : 'LOAD ${_selectedSize.count} EXPOSURES',
                    style: const TextStyle(
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
    ),
  );
}

class _LockedRecipeRow extends StatelessWidget {
  const _LockedRecipeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value, locked for this Film Roll',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: Color(0xFFF4C44F),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Tooltip(
              message: value,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.size,
    required this.isSelected,
    required this.onTap,
  });

  final FilmRollSize size;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: isSelected,
    button: true,
    label: '${size.count} exposure roll',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('start-roll-size-${size.count}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF4C44F)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF4C44F)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                size.count.toString(),
                style: TextStyle(
                  color: isSelected ? const Color(0xFF161616) : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'FRAMES',
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF161616).withValues(alpha: 0.75)
                      : Colors.white54,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
