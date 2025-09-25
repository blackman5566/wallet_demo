import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_demo/features/wallet/data/core/keyService/core/key_service.dart';
import 'package:wallet_demo/features/wallet/data/providers/wallet_providers.dart';

import '../../data/core/keyService/keyServiceProvider.dart';
import '../../data/providers/wallet_notifier.dart';

/// ---------------------------------------------------------------------------
/// ImportMnemonicSheet（匯入助記詞的 BottomSheet）
///
/// 功能：
/// - 提供一個輸入框，讓使用者貼上 12/24 字的助記詞。
/// - 匯入後會：
///   1) 更新錢包相關的 provider 狀態。
///   2) 初始化錢包。
///   3) 關閉 bottom sheet 並提示成功或失敗。
///
/// 為什麼用 ConsumerStatefulWidget？
/// - 需要一個 TextEditingController（有生命週期，要記得 dispose）。
/// - 需要 ref 來操作 Riverpod provider（ConsumerWidget 也能，但這裡要搭配 state）。
/// ---------------------------------------------------------------------------
class ImportMnemonicSheet extends ConsumerStatefulWidget {
  const ImportMnemonicSheet({super.key});
  @override
  ConsumerState<ImportMnemonicSheet> createState() => _ImportMnemonicSheetState();
}

class _ImportMnemonicSheetState extends ConsumerState<ImportMnemonicSheet> {
  // 控制輸入框文字的 controller
  final _mnemonicCtrl = TextEditingController();

  @override
  void dispose() {
    // Widget 銷毀時記得釋放 controller，避免記憶體洩漏
    _mnemonicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        // 鍵盤彈出時，底部 padding 會自動加上鍵盤高度，避免被遮住
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 標題
          Text('Import a seed ', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),

          // 多行文字輸入框（讓使用者貼助記詞）
          TextField(
            controller: _mnemonicCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Paste 12/24-word seed (space-separated)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 匯入按鈕
          FilledButton(
            onPressed: () async {
              try {
                // 呼叫 keyServiceProvider 的 importMnemonic，匯入助記詞
                await ref
                    .read(keyServiceProvider)
                    .importMnemonic(_mnemonicCtrl.text, index: 0);

                // 匯入後讓相關 provider 重算
                ref.invalidate(walletExistsProvider);
                ref.invalidate(accountsListProvider);
                ref.invalidate(currentAccountIndexProvider);
                ref.invalidate(currentAccountNameProvider);

                // 重新初始化錢包
                await ref.read(walletProvider.notifier).init();

                if (!mounted) return;
                Navigator.pop(context); // 關閉 bottom sheet
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Wallet imported')));
              } catch (e) {
                // 匯入失敗，顯示錯誤訊息
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Import failed：$e')));
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}
