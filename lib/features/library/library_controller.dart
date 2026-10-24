import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../services/library/library_scanner.dart';
import '../../services/library/permission_gateway.dart';

final permissionGatewayProvider = Provider<PermissionGateway>(
  (ref) => AndroidPermissionGateway(),
);

final libraryScannerProvider = Provider<LibraryScanner>(
  (ref) => IsolateLibraryScanner(),
);

/// Where to look and where to cache artwork; overridable in tests.
final scanRootsProvider = Provider<Future<List<String>> Function()>(
  (ref) => defaultScanRoots,
);

final artworkDirProvider = Provider<Future<String> Function()>(
  (ref) =>
      () async =>
          p.join((await getApplicationSupportDirectory()).path, 'artwork'),
);

@immutable
class LibraryState {
  const LibraryState({
    this.access,
    this.scanning = false,
    this.error,
    this.lastScanMs,
  });

  /// Null until the first permission check finishes.
  final LibraryAccess? access;
  final bool scanning;
  final String? error;
  final int? lastScanMs;

  LibraryState copyWith({
    LibraryAccess? access,
    bool? scanning,
    Object? error = _unset,
    int? lastScanMs,
  }) => LibraryState(
    access: access ?? this.access,
    scanning: scanning ?? this.scanning,
    error: identical(error, _unset) ? this.error : error as String?,
    lastScanMs: lastScanMs ?? this.lastScanMs,
  );
}

const Object _unset = Object();

class LibraryController extends Notifier<LibraryState> {
  @override
  LibraryState build() => const LibraryState();

  /// Checks access and, if granted, runs an incremental scan.
  Future<void> init() async {
    final access = await ref.read(permissionGatewayProvider).status();
    state = state.copyWith(access: access);
    if (access == LibraryAccess.granted) await rescan();
  }

  Future<void> requestAccess() async {
    final gateway = ref.read(permissionGatewayProvider);
    final access = await gateway.request();
    state = state.copyWith(access: access);
    if (access == LibraryAccess.granted) await rescan();
  }

  Future<void> openSettings() =>
      ref.read(permissionGatewayProvider).openSettings();

  /// Re-reads the permission (e.g. after returning from system settings).
  Future<void> refreshAccess() async {
    final access = await ref.read(permissionGatewayProvider).status();
    final granted =
        access == LibraryAccess.granted &&
        state.access != LibraryAccess.granted;
    state = state.copyWith(access: access);
    if (granted) await rescan();
  }

  Future<void> rescan() async {
    if (state.scanning) return;
    state = state.copyWith(scanning: true, error: null);
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final result = await ref
          .read(libraryScannerProvider)
          .scan(
            ScanRequest(
              roots: await ref.read(scanRootsProvider)(),
              artworkDir: await ref.read(artworkDirProvider)(),
              known: await repo.knownFiles(),
            ),
          );
      await repo.applyScan(result);
      state = state.copyWith(
        scanning: false,
        lastScanMs: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      state = state.copyWith(
        scanning: false,
        error: 'Could not scan your music. Try again.',
      );
      debugPrint('Library scan failed: $e');
    }
  }
}

final libraryControllerProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);
