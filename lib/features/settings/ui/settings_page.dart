import 'package:flutter/material.dart';
import '../../wallet/ui/sheets/ExportMnemonicSheet.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _showExportMnemonic(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.6),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias, // 讓圓角生效
      builder: (_) => const ExportMnemonicSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: const Text('Export seed'),
            subtitle: const Text('Unlock with password to view. Screenshots blocked, time-limited.'),
            onTap: () => _showExportMnemonic(context),
          ),
          const Divider(height: 0),
          // 之後想加其它設定項目就往下放
        ],
      ),
    );
  }
}
