import 'package:flutter/material.dart';
import 'package:rana/features/film_roll/model/film_roll.dart';
import 'package:rana/features/film_roll/model/film_roll_lifecycle.dart';
import 'package:rana/features/film_roll/widgets/contact_sheet_export.dart';

/// Bottom sheet with the active roll's locked recipe and lifecycle actions.
class RollInfoSheet extends StatefulWidget {
  /// Creates the active Film Roll information sheet.
  const RollInfoSheet({
    required this.roll,
    required this.presetName,
    required this.aspectRatioLabel,
    required this.pendingExposures,
    required this.pendingSaveState,
    required this.recipeStatus,
    required this.onEnd,
    required this.onAbandon,
    this.reconciliationRequired = false,
    this.onExportContactSheet,
    this.onRetryRecipe,
    this.onRetryPendingSave,
    this.actionError,
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

  /// Whether an accepted frame is still saving or needs recovery.
  final FilmRollPendingSaveState pendingSaveState;

  /// Availability of the locked camera recipe.
  final FilmRollRecipeStatus recipeStatus;

  /// Whether Android metadata must be reconciled before shooting continues.
  final bool reconciliationRequired;

  /// Archives the active roll as completed.
  final Future<FilmRollActionResult> Function() onEnd;

  /// Deletes only the roll grouping.
  final Future<FilmRollActionResult> Function() onAbandon;

  /// Builds and opens the share sheet for the roll's durable saved frames.
  final Future<ContactSheetExportResult> Function()? onExportContactSheet;

  /// Attempts to reapply a missing or failed locked recipe.
  final Future<FilmRollActionResult> Function()? onRetryRecipe;

  /// Retries a native frame whose durable Film Roll save failed.
  final Future<FilmRollActionResult> Function()? onRetryPendingSave;

  /// Latest safe controller-level action error.
  final String? actionError;

  @override
  State<RollInfoSheet> createState() => _RollInfoSheetState();
}

class _RollInfoSheetState extends State<RollInfoSheet> {
  bool _isSubmitting = false;
  bool _isExporting = false;
  String? _errorMessage;
  String? _exportMessage;

  bool get _isBusy => _isSubmitting || _isExporting;

  bool get _isProcessing => widget.pendingExposures > 0;
  bool get _hasSaveRecovery =>
      widget.pendingSaveState == FilmRollPendingSaveState.recoveryRequired;
  bool get _hasUnsettledSave =>
      widget.pendingSaveState != FilmRollPendingSaveState.idle;
  bool get _recipeUnavailable =>
      widget.recipeStatus == FilmRollRecipeStatus.unavailable;
  bool get _canExport =>
      !_isBusy &&
      widget.onExportContactSheet != null &&
      widget.roll.exposuresTaken > 0 &&
      !_isProcessing &&
      !_hasUnsettledSave &&
      !widget.reconciliationRequired;
  bool get _canChangeLifecycle =>
      !_isProcessing &&
      !_hasSaveRecovery &&
      // A missing locked recipe is a safe terminal path: capture remains
      // blocked, but the user can still end or abandon the grouping. The
      // controller applies the same exception around reconciliation state.
      (widget.recipeStatus == FilmRollRecipeStatus.unavailable ||
          !widget.reconciliationRequired) &&
      widget.recipeStatus != FilmRollRecipeStatus.applying &&
      !_isBusy;

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

  Future<void> _submit(Future<FilmRollActionResult> Function() action) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _exportMessage = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      if (result.succeeded) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            result.message ?? 'This Film Roll action could not finish.';
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'This Film Roll action could not finish. Try again.';
      });
    }
  }

  Future<void> _retry(Future<FilmRollActionResult> Function()? action) async {
    if (_isBusy || action == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _exportMessage = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = result.succeeded
            ? null
            : (result.message ?? 'Recovery did not finish. Try again.');
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Recovery did not finish. Try again.';
      });
    }
  }

  Future<void> _exportContactSheet() async {
    final export = widget.onExportContactSheet;
    if (!_canExport || export == null) return;

    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _exportMessage = null;
    });
    try {
      final result = await export();
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        if (!result.succeeded) {
          _errorMessage =
              result.message ??
              'Could not prepare the contact sheet. Try again.';
          return;
        }
        _exportMessage =
            result.exportedFrameCount == result.historicalFrameCount
            ? 'CONTACT SHEET READY: ${result.exportedFrameCount} '
                  '${result.exportedFrameCount == 1 ? 'FRAME' : 'FRAMES'}'
            : 'CONTACT SHEET READY: ${result.exportedFrameCount} OF '
                  '${result.historicalFrameCount} FRAMES';
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _errorMessage = 'Could not prepare the contact sheet. Try again.';
      });
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: !_isBusy,
    builder: (dialogContext) => PopScope(
      canPop: !_isBusy,
      child: AlertDialog(
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
    ),
  );

  @override
  Widget build(BuildContext context) {
    final combinedError = _errorMessage ?? widget.actionError;
    final pendingExposureLabel = widget.pendingExposures == 1
        ? 'FRAME'
        : 'FRAMES';
    return SafeArea(
      top: false,
      child: PopScope(
        canPop: !_isBusy,
        child: LayoutBuilder(
          builder: (context, constraints) => Container(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * 0.92,
            ),
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
                        key: const ValueKey<String>('roll-info-close-button'),
                        tooltip: 'Close',
                        onPressed: _isBusy
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white70,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                  _InfoRow(
                    label: 'PRESET',
                    value: widget.presetName.toUpperCase(),
                  ),
                  _InfoRow(label: 'FORMAT', value: widget.aspectRatioLabel),
                  _InfoRow(
                    label: 'EXPOSURES',
                    value:
                        '${widget.roll.exposuresTaken}/${widget.roll.size.count}',
                  ),
                  _InfoRow(
                    label: 'REMAINING',
                    value: '${widget.roll.remainingExposures}',
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 14),
                    _StatusNotice(
                      key: const ValueKey<String>('roll-processing-notice'),
                      color: const Color(0xFFF4C44F),
                      message:
                          'PROCESSING ${widget.pendingExposures} '
                          '$pendingExposureLabel',
                    ),
                  ],
                  if (_hasSaveRecovery) ...[
                    const SizedBox(height: 14),
                    const _StatusNotice(
                      key: ValueKey<String>('roll-save-recovery-notice'),
                      color: Color(0xFFE57373),
                      message: 'A SAVED FRAME NEEDS RECOVERY BEFORE SHOOTING.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey<String>('retry-roll-save-button'),
                      onPressed: _isBusy || widget.onRetryPendingSave == null
                          ? null
                          : () => _retry(widget.onRetryPendingSave),
                      child: const Text('RETRY SAVE'),
                    ),
                  ],
                  if (_recipeUnavailable) ...[
                    const SizedBox(height: 14),
                    const _StatusNotice(
                      key: ValueKey<String>('roll-recipe-recovery-notice'),
                      color: Color(0xFFE57373),
                      message:
                          'THE LOCKED RECIPE IS UNAVAILABLE. '
                          'SHOOTING IS PAUSED.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey<String>('retry-roll-recipe-button'),
                      onPressed: _isBusy || widget.onRetryRecipe == null
                          ? null
                          : () => _retry(widget.onRetryRecipe),
                      child: const Text('RETRY RECIPE'),
                    ),
                  ],
                  if (widget.reconciliationRequired) ...[
                    const SizedBox(height: 14),
                    const _StatusNotice(
                      key: ValueKey<String>('roll-reconciliation-notice'),
                      color: Color(0xFFF4C44F),
                      message:
                          'SAVED FILM ROLL FRAMES ARE BEING RECOVERED '
                          'BEFORE SHOOTING.',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey<String>(
                        'retry-roll-reconciliation-button',
                      ),
                      onPressed: _isBusy || widget.onRetryRecipe == null
                          ? null
                          : () => _retry(widget.onRetryRecipe),
                      child: const Text('RETRY RECOVERY'),
                    ),
                  ],
                  if (combinedError != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        combinedError,
                        key: const ValueKey<String>('roll-info-error'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE57373),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  if (_exportMessage != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _exportMessage!,
                        key: const ValueKey<String>('roll-info-export-status'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFF4C44F),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (widget.onExportContactSheet != null) ...[
                    Semantics(
                      button: true,
                      enabled: _canExport,
                      label: 'Export contact sheet',
                      hint: _exportHint,
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>(
                          'export-contact-sheet-button',
                        ),
                        onPressed: _canExport ? _exportContactSheet : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: const Color(0xFFF4C44F),
                          side: const BorderSide(color: Color(0xFF8F6821)),
                        ),
                        icon: _isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFF4C44F),
                                  ),
                                ),
                              )
                            : const Icon(Icons.grid_view_rounded, size: 19),
                        label: Text(
                          _isExporting
                              ? 'EXPORTING CONTACT SHEET…'
                              : 'EXPORT CONTACT SHEET',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
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
          ),
        ),
      ),
    );
  }

  String get _exportHint {
    if (widget.roll.exposuresTaken == 0) {
      return 'Save a frame before exporting a contact sheet';
    }
    if (_isProcessing || _hasUnsettledSave || widget.reconciliationRequired) {
      return 'Wait for saved Film Roll frames to finish processing';
    }
    if (_isBusy) return 'Contact sheet export is in progress';
    return 'Creates a share-only JPEG from saved Film Roll frames';
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({required this.color, required this.message, super.key});

  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: Padding(
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
