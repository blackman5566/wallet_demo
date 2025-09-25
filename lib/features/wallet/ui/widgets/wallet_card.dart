import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_demo/features/wallet/data/providers/wallet_providers.dart';

import '../../data/core/common/chains.dart';
import '../../data/core/common/format.dart';
import '../../data/providers/wallet_notifier.dart';
import '../../data/providers/wallet_state.dart' hide walletProvider;
import '../utils/short.dart';
import 'account_selector.dart';

/// ----------------------------------------------------------------------------
/// WalletCard（已有錢包時顯示的主卡片）
///
/// 功能：
/// 1) 顯示目前帳號（可複製地址）。
/// 2) 顯示餘額（依鏈別顯示 ETH 或 SOL）。
/// 3) 提供「接收」與「發送」兩個動作按鈕。
///
/// 設計重點：
/// - 這個元件是 `ConsumerWidget`：可以在 `build()` 內直接用 `ref.watch()` 監聽 provider。
/// - 不負責彈出 bottom sheet 本身，而是把動作交給父層（透過 callback）。
///   如此父層可以決定要開 `SendSheet` 或 `SendSolSheet`，職責更清楚。
/// ----------------------------------------------------------------------------
class WalletCard extends ConsumerWidget {
  const WalletCard({super.key, required this.onPressSend, required this.onShowReceive});

  /// 由父層注入的動作：按下「發送」時要做什麼（父層會依鏈別開不同面板）
  final void Function(Chain chain) onPressSend;

  /// 由父層注入的動作：按下「接收」時要做什麼（父層彈出顯示地址的面板）
  final void Function(String address) onShowReceive;

  /// 將 BigInt 餘額用對應鏈別的格式化方式轉成文字
  String _balanceText(WalletState st, Chain chain) {
    final v = st.balanceWei ?? BigInt.zero;
    return '${formatEth(v)} ${chain.displaySymbol}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 取主題色彩，讓卡片背景能和全域風格一致
    final scheme = Theme.of(context).colorScheme;

    // 監聽目前鏈別（決定文字單位、以及發送時要走哪個面板）
    final chain = ref.watch(currentChainProvider);

    // 監聽錢包整體狀態（地址、餘額、忙碌等等）
    final st = ref.watch(walletProvider);

    return Card(
      color: scheme.surfaceContainerHigh, // 使用具層次的表面色
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───────────────── 帳號選擇器（可切換帳號 / 新增帳號 / 刷新餘額）
            const SizedBox(height: 4),
            // 直接嵌入 AccountSelector。這個子元件本身就是 ConsumerWidget，
            // 會自行處理 provider 讀取與刷新邏輯。
            // ignore: prefer_const_constructors
            AccountSelector(),
            const SizedBox(height: 8),

            // ───────────────── 地址區塊（可複製）
            Text('Address', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Row(children: [
              // 使用 AnimatedSwitcher 在地址變更時做淡入淡出
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                  child: SelectableText(
                    st.addressHex == null ? '-' : shortAddr(st.addressHex!),
                    key: ValueKey(st.addressHex), // 地址變更時觸發動畫
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: (st.addressHex ?? '').isEmpty
                    ? null
                    : () async {
                  // 複製完整地址到剪貼簿
                  await Clipboard.setData(ClipboardData(text: st.addressHex!));
                  if (!context.mounted) return; // 若視圖已卸載就不做 UI 操作
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Address copied')));
                },
                icon: const Icon(Icons.copy_all_rounded),
              ),
            ]),

            const SizedBox(height: 16),

            // ───────────────── 餘額區塊（依鏈別顯示單位）
            Text('Balance (${chain.symbol})', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: Text(
                _balanceText(st, chain), // 內部會選擇 formatEth 或 formatSol
                key: ValueKey('${st.balanceWei}-${chain.id}'), // 餘額或鏈別改變時做動畫
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),

            const SizedBox(height: 16),

            // ───────────────── 動作按鈕（接收 / 發送）
            Row(children: [
              // 接收：會呼叫父層注入的 onShowReceive，父層負責彈出面板
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: st.addressHex == null ? null : () => onShowReceive(st.addressHex!),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Receive'),
                ),
              ),
              const SizedBox(width: 12),
              // 發送：呼叫父層注入的 onPressSend，父層依鏈別決定開哪個 Send Sheet
              Expanded(
                child: FilledButton.icon(
                  onPressed: st.addressHex == null ? null : () => onPressSend(chain),
                  icon: const Icon(Icons.call_made),
                  label: const Text('Send'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
