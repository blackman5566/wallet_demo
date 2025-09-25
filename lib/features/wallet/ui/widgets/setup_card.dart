import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_demo/features/wallet/data/providers/wallet_providers.dart';

import '../../data/providers/wallet_notifier.dart';
import '../sheets/import_mnemonic_sheet.dart';

/// ----------------------------------------------------------------------------
/// SetupCard（尚未設定錢包時顯示的卡片）
///
/// 這張卡片出現在「使用者還沒有任何錢包」的情況下，提供兩個動作：
/// 1) 建立新錢包（Create New Wallet）
/// 2) 匯入既有助記詞（Import Mnemonic）
///
/// 新手重點：
/// - 這個元件繼承自 `ConsumerWidget`，代表它可以直接用 Riverpod 的 `ref`
///   來讀取或呼叫 provider（例如 `walletProvider.notifier.createNewWallet()`）。
/// - 這裡沒有本地狀態，所以不需要 StatefulWidget。
/// - 顏色、字型等 UI 風格，是透過 `Theme.of(context)` 向主題系統拿來的。
/// ----------------------------------------------------------------------------
class SetupCard extends ConsumerWidget {
  const SetupCard({super.key});

  /// 打開「匯入助記詞」的 BottomSheet
  /// - `showModalBottomSheet` 會從底部滑出一個面板，讓使用者貼上助記詞。
  /// - `isScrollControlled: true` 代表高度可以依內容/鍵盤撐高。
  void _showImportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ImportMnemonicSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 從主題取用顏色，以符合全 app 統一風格
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surfaceContainerHigh, // 使用較高層次的表面色，與背景做出層次
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 內容多高卡片就多高
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題
            Text('No wallet yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            // 說明文字
            const Text('Import a seed or create a new wallet.'),
            const SizedBox(height: 12),

            // 兩個按鈕：建立新錢包 / 匯入助記詞
            Row(children: [
              // ① 建立新錢包
              // - 呼叫 `walletProvider.notifier.createNewWallet()` 讓商業邏輯層做事。
              // - 成功後顯示一個 SnackBar 當作提示。
              FilledButton(
                onPressed: () async {
                  await ref.read(walletProvider.notifier).createNewWallet();

                  // 有些情況下，建立新錢包會觸發上層畫面自動重建；
                  // 如果你需要更快看到畫面切換，也可以在這裡手動 refresh 某些 provider。
                  // （本範例為「不改原邏輯」示範，所以僅顯示提示訊息即可）

                  if (!context.mounted) return; // 避免在畫面被關閉後還操作 UI
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Wallet created')));
                },
                child: const Text('Create wallet'),
              ),

              const SizedBox(width: 12),

              // ② 匯入助記詞：打開底部面板，讓使用者貼上 12/24 字助記詞
              OutlinedButton(
                onPressed: () => _showImportSheet(context),
                child: const Text('Import seed'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
