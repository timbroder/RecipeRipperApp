import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/sync_provider.dart';
import '../providers/recipe_provider.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '0.1.0+1';
  String _storageUsage = 'Calculating...';
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _calculateStorageUsage();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      // Use default version
    }
  }

  Future<void> _calculateStorageUsage() async {
    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final bytes = await syncProvider.exportService.getStorageUsageBytes();
      if (mounted) {
        setState(() {
          _storageUsage = ExportService.formatBytes(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storageUsage = 'Unable to calculate';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<SyncProvider>(
        builder: (context, syncProvider, child) {
          return ListView(
            children: [
              _buildSection(
                title: 'Processing',
                children: [
                  ListTile(
                    leading: const Icon(Icons.speed),
                    title: const Text('Frame Extraction Rate'),
                    subtitle: const Text('0.6 seconds (default)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showComingSoon('Frame rate settings'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.translate),
                    title: const Text('Transcription Language'),
                    subtitle: const Text('English (default)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showComingSoon('Language settings'),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.delete),
                    title: const Text('Delete Videos After Processing'),
                    subtitle: const Text('Save storage space'),
                    value: true,
                    onChanged: (value) =>
                        _showComingSoon('Video deletion settings'),
                  ),
                ],
              ),
              const Divider(),
              _buildCloudSyncSection(syncProvider),
              const Divider(),
              _buildDataSection(syncProvider),
              const Divider(),
              _buildAboutSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCloudSyncSection(SyncProvider syncProvider) {
    final isIOS = Platform.isIOS || Platform.isMacOS;
    final cloudName = isIOS ? 'iCloud' : 'Google Drive';
    final cloudIcon = isIOS ? Icons.cloud : Icons.cloud_outlined;

    return _buildSection(
      title: 'Cloud Sync',
      children: [
        // Sync toggle
        SwitchListTile(
          secondary: Icon(cloudIcon),
          title: Text('Sync with $cloudName'),
          subtitle: Text(
            syncProvider.isSyncEnabled
                ? (syncProvider.lastSyncTimeFormatted != null
                    ? 'Last synced: ${syncProvider.lastSyncTimeFormatted}'
                    : 'Enabled')
                : 'Keep recipes in sync across devices',
          ),
          value: syncProvider.isSyncEnabled,
          onChanged: syncProvider.isSyncing
              ? null
              : (value) => _toggleSync(syncProvider, value),
        ),

        // Account info
        if (syncProvider.isSignedIn)
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('Account'),
            subtitle: Text(syncProvider.account?.email ?? 'Signed in'),
            trailing: TextButton(
              onPressed: () => _signOut(syncProvider),
              child: const Text('Sign Out'),
            ),
          ),

        // Sync status
        if (syncProvider.isSyncEnabled) ...[
          ListTile(
            leading: _getSyncStatusIcon(syncProvider),
            title: const Text('Sync Status'),
            subtitle: Text(syncProvider.statusText),
            trailing: syncProvider.isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: () => _syncNow(syncProvider),
                    tooltip: 'Sync now',
                  ),
          ),
        ],

        // Error message
        if (syncProvider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              syncProvider.errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _getSyncStatusIcon(SyncProvider syncProvider) {
    switch (syncProvider.status) {
      case SyncStatus.idle:
        return const Icon(Icons.cloud_done);
      case SyncStatus.syncing:
        return const Icon(Icons.sync);
      case SyncStatus.success:
        return Icon(Icons.cloud_done,
            color: Theme.of(context).colorScheme.primary);
      case SyncStatus.error:
        return Icon(Icons.cloud_off,
            color: Theme.of(context).colorScheme.error);
      case SyncStatus.noAccount:
        return const Icon(Icons.cloud_off);
      case SyncStatus.disabled:
        return const Icon(Icons.cloud_off);
    }
  }

  Widget _buildDataSection(SyncProvider syncProvider) {
    return _buildSection(
      title: 'Data',
      children: [
        // Export All
        ListTile(
          leading: _isExporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          title: const Text('Export All Recipes'),
          subtitle: const Text('Save as JSON or Markdown'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isExporting ? null : () => _showExportDialog(syncProvider),
        ),

        // Import
        ListTile(
          leading: _isImporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          title: const Text('Import Recipes'),
          subtitle: const Text('Import from JSON or Markdown file'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _isImporting ? null : () => _importRecipes(syncProvider),
        ),

        // Storage
        ListTile(
          leading: Icon(
            Icons.storage,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Storage Usage'),
          subtitle: Text(_storageUsage),
          onTap: _calculateStorageUsage,
        ),

        // Clear data
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Clear All Data',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: const Text('Delete all recipes permanently'),
          onTap: _showClearDataDialog,
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      title: 'About',
      children: [
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('Version'),
          subtitle: Text(_appVersion),
        ),
        ListTile(
          leading: const Icon(Icons.description),
          title: const Text('Licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'Recipe Ripper',
              applicationVersion: _appVersion,
              applicationLegalese: '© 2026 Recipe Ripper',
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Report an Issue'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _reportIssue,
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('Source Code'),
          subtitle: const Text('View on GitHub'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openGitHub,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
      ],
    );
  }

  // Sync Methods

  Future<void> _toggleSync(SyncProvider syncProvider, bool enabled) async {
    await syncProvider.setSyncEnabled(enabled);
    if (enabled && mounted) {
      _showSnackBar('Sync enabled. Syncing now...');
    }
  }

  Future<void> _syncNow(SyncProvider syncProvider) async {
    final result = await syncProvider.syncNow();
    if (mounted) {
      if (result.success) {
        _showSnackBar(
          'Synced: ${result.uploadedCount} uploaded, ${result.downloadedCount} downloaded',
        );
        // Refresh recipes
        Provider.of<RecipeProvider>(context, listen: false).refresh();
      } else {
        _showSnackBar(
            'Sync failed: ${result.errors.firstOrNull ?? "Unknown error"}');
      }
    }
  }

  Future<void> _signOut(SyncProvider syncProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Your recipes will remain on this device but will no longer sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await syncProvider.signOut();
      if (mounted) {
        _showSnackBar('Signed out');
      }
    }
  }

  // Export Methods

  Future<void> _showExportDialog(SyncProvider syncProvider) async {
    final format = await showDialog<ExportFormat>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export Format'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ExportFormat.json),
            child: const ListTile(
              leading: Icon(Icons.code),
              title: Text('JSON'),
              subtitle: Text('Can be re-imported into the app'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ExportFormat.markdown),
            child: const ListTile(
              leading: Icon(Icons.description),
              title: Text('Markdown'),
              subtitle: Text('Human-readable format'),
            ),
          ),
        ],
      ),
    );

    if (format == null) return;

    setState(() => _isExporting = true);

    try {
      final exportService = syncProvider.exportService;
      final result = format == ExportFormat.json
          ? await exportService.exportAllRecipesAndShare()
          : await exportService.exportAllRecipesToMarkdown();

      if (result.success) {
        if (format == ExportFormat.markdown && result.content != null) {
          // For markdown, we need to create and share the file
          await _shareMarkdown(exportService, result.content!);
        }
        _showSnackBar('Export successful');
      } else {
        _showSnackBar('Export failed: ${result.errorMessage}');
      }
    } catch (e) {
      _showSnackBar('Export error: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareMarkdown(
      ExportService exportService, String content) async {
    // The share functionality is handled within the export service
    // This is just a placeholder for potential additional logic
  }

  // Import Methods

  Future<void> _importRecipes(SyncProvider syncProvider) async {
    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Import Options'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImportMode.skipDuplicates),
            child: const ListTile(
              leading: Icon(Icons.skip_next),
              title: Text('Skip Duplicates'),
              subtitle: Text('Keep existing recipes'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, ImportMode.replaceDuplicates),
            child: const ListTile(
              leading: Icon(Icons.swap_horiz),
              title: Text('Replace Duplicates'),
              subtitle: Text('Overwrite existing recipes'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, ImportMode.renameDuplicates),
            child: const ListTile(
              leading: Icon(Icons.copy),
              title: Text('Rename Duplicates'),
              subtitle: Text('Keep both versions'),
            ),
          ),
        ],
      ),
    );

    if (mode == null) return;

    setState(() => _isImporting = true);

    try {
      final importService = syncProvider.importService;
      final result = await importService.pickAndImportFile(mode: mode);

      if (mounted) {
        if (result.success) {
          _showSnackBar(
            'Imported ${result.importedCount} recipes'
            '${result.skippedCount > 0 ? ', skipped ${result.skippedCount}' : ''}',
          );
          // Refresh recipes
          Provider.of<RecipeProvider>(context, listen: false).refresh();
          _calculateStorageUsage();
        } else {
          _showSnackBar('Import failed: ${result.errorMessage}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Import error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  // Clear Data

  Future<void> _showClearDataDialog() async {
    final recipeProvider =
        Provider.of<RecipeProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all recipes. This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await recipeProvider.clearAllRecipes();
        _showSnackBar('All data cleared');
        _calculateStorageUsage();
      } catch (e) {
        _showSnackBar('Error clearing data: $e');
      }
    }
  }

  // External Links

  Future<void> _reportIssue() async {
    final uri =
        Uri.parse('https://github.com/timbroder/RecipeRipperApp/issues/new');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not open browser');
    }
  }

  Future<void> _openGitHub() async {
    final uri = Uri.parse('https://github.com/timbroder/RecipeRipperApp');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not open browser');
    }
  }

  // Utilities

  void _showComingSoon(String feature) {
    _showSnackBar('$feature will be available in a future update');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
