import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import 'database_service.dart';
import 'export_service.dart';
import 'import_service.dart';

/// Sync status enumeration
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  noAccount,
  disabled,
}

/// Sync direction
enum SyncDirection {
  upload,
  download,
  bidirectional,
}

/// Sync conflict resolution strategy
enum ConflictResolution {
  /// Server version wins
  serverWins,

  /// Local version wins
  localWins,

  /// Most recent version wins
  newestWins,
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int uploadedCount;
  final int downloadedCount;
  final int conflictsResolved;
  final List<String> errors;
  final DateTime? lastSyncTime;

  SyncResult({
    required this.success,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.conflictsResolved = 0,
    this.errors = const [],
    this.lastSyncTime,
  });

  factory SyncResult.failure(String error) {
    return SyncResult(success: false, errors: [error]);
  }
}

/// Sync account info
class SyncAccount {
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isSignedIn;

  SyncAccount({
    this.email,
    this.displayName,
    this.photoUrl,
    required this.isSignedIn,
  });

  factory SyncAccount.notSignedIn() {
    return SyncAccount(isSignedIn: false);
  }
}

/// Abstract base class for cloud sync services
abstract class CloudSyncService {
  /// Get the current sync status
  SyncStatus get status;

  /// Get the current account info
  Future<SyncAccount> getAccount();

  /// Sign in to the cloud service
  Future<bool> signIn();

  /// Sign out from the cloud service
  Future<void> signOut();

  /// Check if sync is enabled
  Future<bool> isSyncEnabled();

  /// Enable or disable sync
  Future<void> setSyncEnabled(bool enabled);

  /// Sync recipes with the cloud
  Future<SyncResult> sync({
    SyncDirection direction = SyncDirection.bidirectional,
    ConflictResolution conflictResolution = ConflictResolution.newestWins,
  });

  /// Get the last sync time
  Future<DateTime?> getLastSyncTime();

  /// Force upload all recipes to cloud
  Future<SyncResult> forceUpload();

  /// Force download all recipes from cloud
  Future<SyncResult> forceDownload();
}

/// iOS iCloud sync service using platform channels
class ICloudSyncService extends CloudSyncService {
  static const _channel = MethodChannel('com.reciperipperapp/icloud');
  static const _prefsKeyEnabled = 'icloud_sync_enabled';
  static const _prefsKeyLastSync = 'icloud_last_sync';

  final ExportService _exportService;
  final ImportService _importService;

  SyncStatus _status = SyncStatus.idle;

  ICloudSyncService(
    DatabaseService databaseService,
    this._exportService,
    this._importService,
  );

  @override
  SyncStatus get status => _status;

  @override
  Future<SyncAccount> getAccount() async {
    try {
      final result = await _channel.invokeMethod<Map>('getAccount');
      if (result != null && result['isSignedIn'] == true) {
        return SyncAccount(
          email: result['email'] as String?,
          displayName: result['displayName'] as String?,
          isSignedIn: true,
        );
      }
      return SyncAccount.notSignedIn();
    } on PlatformException {
      return SyncAccount.notSignedIn();
    }
  }

  @override
  Future<bool> signIn() async {
    // iCloud doesn't require explicit sign-in, it uses the system account
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    // iCloud can't sign out programmatically
    await setSyncEnabled(false);
  }

  @override
  Future<bool> isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyEnabled) ?? false;
  }

  @override
  Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, enabled);
  }

  @override
  Future<SyncResult> sync({
    SyncDirection direction = SyncDirection.bidirectional,
    ConflictResolution conflictResolution = ConflictResolution.newestWins,
  }) async {
    if (!(await isSyncEnabled())) {
      return SyncResult.failure('Sync is disabled');
    }

    _status = SyncStatus.syncing;

    try {
      final result = await _exportService.exportAllRecipesToJson();
      if (!result.success) {
        _status = SyncStatus.error;
        return SyncResult.failure(result.errorMessage ?? 'Export failed');
      }

      // Upload to iCloud
      await _channel.invokeMethod('saveToICloud', {
        'filename': 'recipes.json',
        'content': result.content,
      });

      // Download from iCloud
      final cloudContent =
          await _channel.invokeMethod<String>('loadFromICloud', {
        'filename': 'recipes.json',
      });

      var downloadedCount = 0;
      if (cloudContent != null && cloudContent.isNotEmpty) {
        final importResult = await _importService.importFromJson(
          cloudContent,
          mode: ImportMode.skipDuplicates,
        );
        downloadedCount = importResult.importedCount;
      }

      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString(_prefsKeyLastSync, now.toIso8601String());

      _status = SyncStatus.success;
      return SyncResult(
        success: true,
        uploadedCount: 1,
        downloadedCount: downloadedCount,
        lastSyncTime: now,
      );
    } on PlatformException catch (e) {
      _status = SyncStatus.error;
      return SyncResult.failure('iCloud sync failed: ${e.message}');
    } catch (e) {
      _status = SyncStatus.error;
      return SyncResult.failure('Sync failed: $e');
    }
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_prefsKeyLastSync);
    if (timeStr != null) {
      return DateTime.tryParse(timeStr);
    }
    return null;
  }

  @override
  Future<SyncResult> forceUpload() async {
    return sync(direction: SyncDirection.upload);
  }

  @override
  Future<SyncResult> forceDownload() async {
    _status = SyncStatus.syncing;

    try {
      final cloudContent =
          await _channel.invokeMethod<String>('loadFromICloud', {
        'filename': 'recipes.json',
      });

      if (cloudContent == null || cloudContent.isEmpty) {
        _status = SyncStatus.success;
        return SyncResult(success: true, downloadedCount: 0);
      }

      final importResult = await _importService.importFromJson(
        cloudContent,
        mode: ImportMode.replaceDuplicates,
      );

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString(_prefsKeyLastSync, now.toIso8601String());

      _status = SyncStatus.success;
      return SyncResult(
        success: importResult.success,
        downloadedCount: importResult.importedCount,
        lastSyncTime: now,
        errors: importResult.errors,
      );
    } on PlatformException catch (e) {
      _status = SyncStatus.error;
      return SyncResult.failure('iCloud download failed: ${e.message}');
    } catch (e) {
      _status = SyncStatus.error;
      return SyncResult.failure('Download failed: $e');
    }
  }
}

/// Android Google Drive sync service
class GoogleDriveSyncService extends CloudSyncService {
  static const _prefsKeyEnabled = 'gdrive_sync_enabled';
  static const _prefsKeyLastSync = 'gdrive_last_sync';
  static const _folderName = 'RecipeRipper';
  static const _fileName = 'recipes.json';

  final DatabaseService _databaseService;
  final ExportService _exportService;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  SyncStatus _status = SyncStatus.idle;
  drive.DriveApi? _driveApi;

  GoogleDriveSyncService(
    this._databaseService,
    this._exportService,
    ImportService importService,
  );

  @override
  SyncStatus get status => _status;

  @override
  Future<SyncAccount> getAccount() async {
    final account = _googleSignIn.currentUser;
    if (account != null) {
      return SyncAccount(
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        isSignedIn: true,
      );
    }

    // Try to sign in silently
    final silentAccount = await _googleSignIn.signInSilently();
    if (silentAccount != null) {
      await _initDriveApi();
      return SyncAccount(
        email: silentAccount.email,
        displayName: silentAccount.displayName,
        photoUrl: silentAccount.photoUrl,
        isSignedIn: true,
      );
    }

    return SyncAccount.notSignedIn();
  }

  @override
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _initDriveApi();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
    await setSyncEnabled(false);
  }

  Future<void> _initDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient != null) {
      _driveApi = drive.DriveApi(httpClient);
    }
  }

  @override
  Future<bool> isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyEnabled) ?? false;
  }

  @override
  Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, enabled);
  }

  @override
  Future<SyncResult> sync({
    SyncDirection direction = SyncDirection.bidirectional,
    ConflictResolution conflictResolution = ConflictResolution.newestWins,
  }) async {
    if (!(await isSyncEnabled())) {
      return SyncResult.failure('Sync is disabled');
    }

    if (_driveApi == null) {
      final account = await getAccount();
      if (!account.isSignedIn) {
        return SyncResult.failure('Not signed in to Google');
      }
      await _initDriveApi();
    }

    if (_driveApi == null) {
      return SyncResult.failure('Failed to initialize Google Drive');
    }

    _status = SyncStatus.syncing;

    try {
      // Get or create the app folder
      final folderId = await _getOrCreateFolder();
      if (folderId == null) {
        _status = SyncStatus.error;
        return SyncResult.failure('Failed to create sync folder');
      }

      var uploadedCount = 0;
      var downloadedCount = 0;
      var conflictsResolved = 0;

      // Download cloud recipes first
      final cloudRecipes = await _downloadRecipes(folderId);

      // Get local recipes
      final localRecipes = await _databaseService.getAllRecipes();

      // Handle sync based on direction and conflict resolution
      if (direction == SyncDirection.bidirectional ||
          direction == SyncDirection.download) {
        for (final cloudRecipe in cloudRecipes) {
          final localRecipe = localRecipes.firstWhere(
            (r) => r.id == cloudRecipe.id || r.title == cloudRecipe.title,
            orElse: () => Recipe(title: ''),
          );

          if (localRecipe.title.isEmpty) {
            // New recipe from cloud
            await _databaseService.insertRecipe(cloudRecipe);
            downloadedCount++;
          } else if (_shouldReplaceLocal(
              localRecipe, cloudRecipe, conflictResolution)) {
            // Update local with cloud version
            await _databaseService.updateRecipe(
              cloudRecipe.copyWith(id: localRecipe.id),
            );
            conflictsResolved++;
          }
        }
      }

      if (direction == SyncDirection.bidirectional ||
          direction == SyncDirection.upload) {
        // Upload all local recipes
        final exportResult = await _exportService.exportAllRecipesToJson();
        if (exportResult.success && exportResult.content != null) {
          await _uploadRecipes(folderId, exportResult.content!);
          uploadedCount = localRecipes.length;
        }
      }

      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString(_prefsKeyLastSync, now.toIso8601String());

      _status = SyncStatus.success;
      return SyncResult(
        success: true,
        uploadedCount: uploadedCount,
        downloadedCount: downloadedCount,
        conflictsResolved: conflictsResolved,
        lastSyncTime: now,
      );
    } catch (e) {
      _status = SyncStatus.error;
      return SyncResult.failure('Sync failed: $e');
    }
  }

  bool _shouldReplaceLocal(
    Recipe local,
    Recipe cloud,
    ConflictResolution resolution,
  ) {
    switch (resolution) {
      case ConflictResolution.serverWins:
        return true;
      case ConflictResolution.localWins:
        return false;
      case ConflictResolution.newestWins:
        return cloud.updatedAt.isAfter(local.updatedAt);
    }
  }

  Future<String?> _getOrCreateFolder() async {
    try {
      // Search for existing folder
      const query =
          "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
      final fileList = await _driveApi!.files.list(q: query, spaces: 'drive');

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }

      // Create new folder
      final folder = drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await _driveApi!.files.create(folder);
      return createdFolder.id;
    } catch (e) {
      debugPrint('Error getting/creating folder: $e');
      return null;
    }
  }

  Future<List<Recipe>> _downloadRecipes(String folderId) async {
    try {
      final query =
          "name='$_fileName' and '$folderId' in parents and trashed=false";
      final fileList = await _driveApi!.files.list(q: query, spaces: 'drive');

      if (fileList.files == null || fileList.files!.isEmpty) {
        return [];
      }

      final fileId = fileList.files!.first.id;
      if (fileId == null) return [];

      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await media.stream.toList();
      final content = utf8.decode(bytes.expand((x) => x).toList());

      final data = json.decode(content);
      if (data is Map<String, dynamic> && data.containsKey('recipes')) {
        return (data['recipes'] as List)
            .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error downloading recipes: $e');
      return [];
    }
  }

  Future<void> _uploadRecipes(String folderId, String content) async {
    try {
      // Check if file exists
      final query =
          "name='$_fileName' and '$folderId' in parents and trashed=false";
      final fileList = await _driveApi!.files.list(q: query, spaces: 'drive');

      final media = drive.Media(
        Stream.value(utf8.encode(content)),
        utf8.encode(content).length,
        contentType: 'application/json',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Update existing file
        final fileId = fileList.files!.first.id;
        if (fileId != null) {
          await _driveApi!.files.update(
            drive.File(),
            fileId,
            uploadMedia: media,
          );
        }
      } else {
        // Create new file
        final file = drive.File()
          ..name = _fileName
          ..parents = [folderId]
          ..mimeType = 'application/json';

        await _driveApi!.files.create(file, uploadMedia: media);
      }
    } catch (e) {
      debugPrint('Error uploading recipes: $e');
      rethrow;
    }
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_prefsKeyLastSync);
    if (timeStr != null) {
      return DateTime.tryParse(timeStr);
    }
    return null;
  }

  @override
  Future<SyncResult> forceUpload() async {
    return sync(direction: SyncDirection.upload);
  }

  @override
  Future<SyncResult> forceDownload() async {
    return sync(
      direction: SyncDirection.download,
      conflictResolution: ConflictResolution.serverWins,
    );
  }
}

/// Factory to get the appropriate sync service for the current platform
class CloudSyncServiceFactory {
  static CloudSyncService create(
    DatabaseService databaseService,
    ExportService exportService,
    ImportService importService,
  ) {
    if (Platform.isIOS || Platform.isMacOS) {
      return ICloudSyncService(databaseService, exportService, importService);
    } else {
      return GoogleDriveSyncService(
          databaseService, exportService, importService);
    }
  }
}
