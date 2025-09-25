import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../wallet/ui/wallet_page.dart';
import '../../settings/ui/settings_page.dart';

final tabIndexProvider = StateProvider<int>((_) => 0);

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(tabIndexProvider);

    // 加入 SettingsPage 當第 2 個分頁
    final pages = const [
      WalletPage(),
      SettingsPage(),
    ];

    return Scaffold(
      // ✅ 拿掉 AppBar，並用 SafeArea 讓內容不會被瀏海遮住
      body: SafeArea(
        top: true,
        bottom: false,
        child: IndexedStack(index: idx, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (v) =>
        ref.read(tabIndexProvider.notifier).state = v,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Wallet',
          ),
          // ✅ 底部的設定按鈕，直接切到 SettingsPage
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
