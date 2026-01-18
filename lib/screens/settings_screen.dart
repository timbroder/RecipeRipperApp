import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _appVersion = '0.1.0+1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSection(
            title: 'Processing',
            children: [
              ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Frame Extraction Rate'),
                subtitle: const Text('0.6 seconds (default)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement in future sprint
                  _showComingSoon();
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: const Text('Transcription Language'),
                subtitle: const Text('English (default)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement in future sprint
                  _showComingSoon();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.delete),
                title: const Text('Delete Videos After Processing'),
                subtitle: const Text('Save storage space'),
                value: true,
                onChanged: (value) {
                  // TODO: Implement in future sprint
                  _showComingSoon();
                },
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            title: 'Cloud Sync',
            children: [
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('Cloud Sync'),
                subtitle: const Text('Not configured'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement in Sprint 5
                  _showComingSoon();
                },
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            title: 'Data',
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Export All Recipes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement in Sprint 5
                  _showComingSoon();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Import Recipes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Implement in Sprint 5
                  _showComingSoon();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.storage,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Storage Usage'),
                subtitle: const Text('Calculating...'),
                onTap: () {
                  // TODO: Implement storage calculation
                  _showComingSoon();
                },
              ),
            ],
          ),
          const Divider(),
          _buildSection(
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
                onTap: () {
                  // TODO: Link to GitHub issues
                  _showComingSoon();
                },
              ),
            ],
          ),
        ],
      ),
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

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This feature is coming in a future sprint!'),
      ),
    );
  }
}
