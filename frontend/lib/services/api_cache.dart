import 'dart:async';

/// Simple in-memory cache with TTL and in-flight request deduplication.
///
/// Prevents duplicate concurrent API calls for the same key and caches
/// results for a configurable duration.
class ApiCache {
  final Duration defaultTtl;
  final _entries = <String, _CacheEntry>{};
  final _inFlight = <String, Completer<dynamic>>{};

  ApiCache({this.defaultTtl = const Duration(minutes: 5)});

  /// Get a cached value or fetch it using [loader].
  ///
  /// If the same [key] is already being fetched, the existing Future is
  /// returned (deduplication). Results are cached for [ttl] (defaults to
  /// [defaultTtl]). Pass [forceRefresh] to bypass the cache and re-fetch.
  Future<T> get<T>(
    String key,
    Future<T> Function() loader, {
    Duration? ttl,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _entries.remove(key);
      // Also cancel any in-flight request for this key when force refreshing
      // so we don't use stale data from an already-running fetch
      _inFlight.remove(key);
    }

    // Return cached value if still valid
    final entry = _entries[key];
    if (entry != null && !entry.isExpired) {
      return entry.value as T;
    }

    // Deduplicate: if the same key is already being fetched, wait for it
    // Add a safety timeout so we never deadlock on a stuck loader
    if (_inFlight.containsKey(key)) {
      return await _inFlight[key]!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Cache in-flight request timed out: $key'),
      ) as T;
    }

    final completer = Completer<T>();
    _inFlight[key] = completer;
    try {
      final result = await loader();
      _entries[key] = _CacheEntry(result, ttl ?? defaultTtl);
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Invalidate a specific cache entry.
  void invalidate(String key) {
    _entries.remove(key);
  }

  /// Invalidate all entries whose key starts with [prefix].
  void invalidatePrefix(String prefix) {
    _entries.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Clear the entire cache.
  void clear() {
    _entries.clear();
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime _expiresAt;

  _CacheEntry(this.value, Duration ttl) : _expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(_expiresAt);
}
