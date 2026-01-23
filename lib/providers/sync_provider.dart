import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

// Re-export for consumers
export '../services/cloud_sync_service.dart'
    show SyncStatus, SyncAccount, SyncResult;

/// Provider for managing cloud sync state
class SyncProvider extends ChangeNotifier {
  final DatabaseService _databaseService;
  late final ExportService _exportService;
  late final ImportService _importService;
  late final CloudSyncService _syncService;

  SyncStatus _status = SyncStatus.idle;
  SyncAccount? _account;
  DateTime? _lastSyncTime;
  String? _errorMessage;
  bool _isSyncEnabled = false;
  bool _isInitialized = false;

  // Auto-sync timer
  Timer? _autoSyncTimer;
  static const _autoSyncInterval = Duration(minutes: 15);

  SyncProvider(this._databaseService) {
    _exportService = ExportService(_databaseService);
    _importService = ImportService(_databaseService);
    _syncService = CloudSyncServiceFactory.create(
      _databaseService,
      _exportService,
      _importService,
    );
  }

  // Getters
  SyncStatus get status => _status;
  SyncAccount? get account => _account;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;
  bool get isSyncEnabled => _isSyncEnabled;
  bool get isInitialized => _isInitialized;
  bool get isSignedIn => _account?.isSignedIn ?? false;
  bool get isSyncing => _status == SyncStatus.syncing;

  ExportService get exportService => _exportService;
  ImportService get importService => _importService;

  /// Initialize the sync provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isSyncEnabled = await _syncService.isSyncEnabled();
    _lastSyncTime = await _syncService.getLastSyncTime();
    _account = await _syncService.getAccount();

    if (_isSyncEnabled && _account?.isSignedIn == true) {
      _startAutoSync();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Sign in to the cloud service
  Future<bool> signIn() async {
    try {
      _errorMessage = null;
      final success = await _syncService.signIn();

      if (success) {
        _account = await _syncService.getAccount();
        notifyListeners();
      }

      return success;
    } catch (e) {
      _errorMessage = 'Sign in failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sign out from the cloud service
  Future<void> signOut() async {
    try {
      await _syncService.signOut();
      _stopAutoSync();
      _account = SyncAccount.notSignedIn();
      _isSyncEnabled = false;
      _status = SyncStatus.idle;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Sign out failed: $e';
      notifyListeners();
    }
  }

  /// Enable or disable sync
  Future<void> setSyncEnabled(bool enabled) async {
    try {
      if (enabled && !isSignedIn) {
        final success = await signIn();
        if (!success) return;
      }

      await _syncService.setSyncEnabled(enabled);
      _isSyncEnabled = enabled;

      if (enabled) {
        _startAutoSync();
        // Trigger initial sync
        await syncNow();
      } else {
        _stopAutoSync();
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update sync setting: $e';
      notifyListeners();
    }
  }

  /// Manually trigger a sync
  Future<SyncResult> syncNow() async {
    if (!_isSyncEnabled) {
      return SyncResult.failure('Sync is disabled');
    }

    if (!isSignedIn) {
      return SyncResult.failure('Not signed in');
    }

    _status = SyncStatus.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _syncService.sync();

      _status = result.success ? SyncStatus.success : SyncStatus.error;
      _lastSyncTime = result.lastSyncTime ?? DateTime.now();
      _errorMessage = result.errors.isNotEmpty ? result.errors.first : null;

      notifyListeners();
      return result;
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = 'Sync failed: $e';
      notifyListeners();
      return SyncResult.failure(_errorMessage!);
    }
  }

  /// Force upload all local recipes to cloud
  Future<SyncResult> forceUpload() async {
    _status = SyncStatus.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _syncService.forceUpload();
      _status = result.success ? SyncStatus.success : SyncStatus.error;
      _lastSyncTime = result.lastSyncTime ?? DateTime.now();
      _errorMessage = result.errors.isNotEmpty ? result.errors.first : null;
      notifyListeners();
      return result;
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = 'Upload failed: $e';
      notifyListeners();
      return SyncResult.failure(_errorMessage!);
    }
  }

  /// Force download all recipes from cloud
  Future<SyncResult> forceDownload() async {
    _status = SyncStatus.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _syncService.forceDownload();
      _status = result.success ? SyncStatus.success : SyncStatus.error;
      _lastSyncTime = result.lastSyncTime ?? DateTime.now();
      _errorMessage = result.errors.isNotEmpty ? result.errors.first : null;
      notifyListeners();
      return result;
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = 'Download failed: $e';
      notifyListeners();
      return SyncResult.failure(_errorMessage!);
    }
  }

  /// Start auto-sync timer
  void _startAutoSync() {
    _stopAutoSync();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) {
      if (_isSyncEnabled && isSignedIn) {
        syncNow();
      }
    });
  }

  /// Stop auto-sync timer
  void _stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Get formatted last sync time string
  String? get lastSyncTimeFormatted {
    if (_lastSyncTime == null) return null;

    final now = DateTime.now();
    final diff = now.difference(_lastSyncTime!);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  /// Get sync status text
  String get statusText {
    switch (_status) {
      case SyncStatus.idle:
        return _isSyncEnabled ? 'Ready' : 'Disabled';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.success:
        return 'Synced';
      case SyncStatus.error:
        return _errorMessage ?? 'Error';
      case SyncStatus.noAccount:
        return 'Not signed in';
      case SyncStatus.disabled:
        return 'Disabled';
    }
  }

  @override
  void dispose() {
    _stopAutoSync();
    super.dispose();
  }
}
