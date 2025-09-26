import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wallet_demo/features/wallet/ui/sheets/send_sheet.dart';
import 'package:wallet_demo/features/wallet/data/providers/wallet_providers.dart';
import 'package:wallet_demo/features/wallet/ui/sheets/sol_send_sheet.dart';

import '../data/core/common/chains.dart';
import '../data/core/service/evm/tx_watcher_provider.dart';
import '../data/providers/wallet_notifier.dart';
import 'widgets/top_bar.dart';
import 'widgets/setup_card.dart';
import 'widgets/wallet_card.dart';
import 'sheets/receive_address_sheet.dart';

/// ---------------------------------------------------------------------------
/// WalletPage（錢包主頁）
/// - 這個頁面負責：
///   1) 在啟動時初始化錢包狀態（init）。
///   2) 依照「是否已存在錢包」顯示不同卡片（SetupCard / WalletCard）。
///   3) 轉發「發送」與「接收」的動作，彈出對應的底部面板（BottomSheet）。
/// - 使用 Riverpod 的 ConsumerStatefulWidget：
///   - Stateful：頁面本身有生命週期（initState、dispose 等）。
///   - Consumer：可以拿到 ref 來監聽/讀取 provider 狀態（ref.watch / ref.read）。
/// ---------------------------------------------------------------------------
class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  ProviderSubscription? _sub;
  @override
  void initState() {
    super.initState();
    // ⚠️ 在頁面建立後「儘快」呼叫初始化：
    // 使用 microtask 避免在 build 之前就動到 provider 造成時序問題。
    //檢查是不是有注記詞
    Future.microtask(() => ref.read(walletProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    //final tx = ref.watch(txWatcherProvider);
    final st = ref.watch(walletProvider);// 監聽錢包整體狀態（例如：loading、餘額、地址等）
    final exists = ref.watch(walletExistsProvider); // 查詢是否已存在錢包（用來決定要顯示 SetupCard 還是 WalletCard）

    // 若錢包仍在初始化/讀取中，顯示一個 loading 圈圈
    if (st.loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 頂部列：切換鏈（EVM/SOL）等
          const TopBar(),
          const SizedBox(height: 12),

          // 中央區塊：根據是否已有錢包顯示不同卡片
          Expanded(
            child: exists.when(
              loading: () => const SizedBox.shrink(), // exists 還在查詢中
              error: (_, __) => const SizedBox.shrink(), // 這裡簡化處理錯誤
              data: (has) {
                // 沒有錢包或還沒取到地址 → 顯示「建立/匯入」卡片
                if (!has || st.addressHex == null) {
                  return topCard(const SetupCard());
                }

                // 已有錢包 → 顯示主卡片（地址、餘額、發送/接收）
                return topCard(
                  WalletCard(
                    onPressSend: _onPressSend, // 按「發送」時要做的事
                    onShowReceive: _showReceiveSheet, // 按「接收」時要做的事
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 小工具：把內容置頂且限制最大寬度，讓大螢幕（平板/桌機）排版更好看
  Widget topCard(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: child,
    ),
  );

  /// 依「目前鏈別」打開發送面板
  void _onPressSend(Chain chain) {
    if (chain.kind == ChainKind.sol) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // 允許內容撐高（如有鍵盤彈出）
        builder: (_) => const SendSheetSol(),
      );
    }else{
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // 允許內容撐高（如有鍵盤彈出）
        builder: (_) => const SendSheet(),
      );
    }
  }

  /// 打開「接收地址」的面板（顯示地址、可複製）
  void _showReceiveSheet(String address) {
    showModalBottomSheet(
      context: context,
      builder: (_) => ReceiveAddressSheet(address: address),
    );
  }
}
