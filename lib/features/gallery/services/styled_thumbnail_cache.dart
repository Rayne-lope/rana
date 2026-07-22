import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:rana/core/utils/app_logger.dart';

/// In-memory LRU and disk cache for rendered styled thumbnails.
class StyledThumbnailCache {
  StyledThumbnailCache._internal();

  static final StyledThumbnailCache instance = StyledThumbnailCache._internal();

  final int maxMemoryEntries = 100;
  final LinkedHashMap<String, Uint8List> _memoryCache =
      LinkedHashMap<String, Uint8List>();
  Directory? _cacheDir;
  Future<void>? _initFuture;

  Future<void> _ensureInitialized() async {
    _initFuture ??= _init();
    await _initFuture;
  }

  Future<void> _init() async {
    try {
      final tempPath = Directory.systemTemp.path;
      _cacheDir = Directory('$tempPath/rana_styled_thumbnails');
      await _cacheDir!.create(recursive: true);
    } on FileSystemException catch (e, stack) {
      AppLogger.e(
        'StyledThumbnailCache',
        'Failed to initialize cache directory',
        e,
        stack,
      );
    }
  }

  /// Retrieves a cached thumbnail bitmap by [cacheKey].
  Future<Uint8List?> get(String cacheKey) async {
    // 1. Check Memory Cache
    if (_memoryCache.containsKey(cacheKey)) {
      final bytes = _memoryCache.remove(cacheKey)!;
      _memoryCache[cacheKey] = bytes; // Move to end (most recently used)
      return bytes;
    }

    // 2. Check Disk Cache
    await _ensureInitialized();
    if (_cacheDir == null) return null;

    final file = File('${_cacheDir!.path}/${_sanitizeKey(cacheKey)}.jpg');
    try {
      final bytes = await file.readAsBytes();
      _putInMemory(cacheKey, bytes);
      return bytes;
    } on FileSystemException {
      AppLogger.w(
        'StyledThumbnailCache',
        'Failed reading disk cache for key: $cacheKey',
      );
    }

    return null;
  }

  /// Saves a rendered thumbnail bitmap into both memory LRU and disk cache.
  Future<void> put(String cacheKey, Uint8List bytes) async {
    _putInMemory(cacheKey, bytes);

    await _ensureInitialized();
    if (_cacheDir == null) return;

    try {
      final file = File('${_cacheDir!.path}/${_sanitizeKey(cacheKey)}.jpg');
      await file.writeAsBytes(bytes, flush: true);
    } on FileSystemException catch (e, stack) {
      AppLogger.e(
        'StyledThumbnailCache',
        'Failed writing disk cache for key: $cacheKey',
        e,
        stack,
      );
    }
  }

  void _putInMemory(String cacheKey, Uint8List bytes) {
    if (_memoryCache.length >= maxMemoryEntries) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    _memoryCache[cacheKey] = bytes;
  }

  /// Clears in-memory LRU cache.
  void clearMemoryCache() {
    _memoryCache.clear();
  }

  /// Evicts all disk and memory cached entries.
  Future<void> clearAll() async {
    _memoryCache.clear();
    await _ensureInitialized();
    if (_cacheDir != null) {
      try {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      } on FileSystemException catch (e, stack) {
        AppLogger.e(
          'StyledThumbnailCache',
          'Failed clearing disk cache directory',
          e,
          stack,
        );
      }
    }
  }

  String _sanitizeKey(String key) =>
      key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
}
