import 'dart:async' show unawaited; // 引入 unawaited：呼叫非同步函式但不等待結果
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_demo/features/wallet/data/providers/wallet_providers.dart';
import '../../data/core/common/chains.dart';
import '../../data/providers/wallet_notifier.dart';

/// ---------------------------------------------------------------------------
/// TopBar（頁面左上角工具列）
/// - 功能：提供「鏈別切換」（例如：EVM / Solana），並在切換後做一連串刷新。
/// - 這個元件是 ConsumerWidget：
///   - 可在 build 內用 `ref.watch(...)` 讀取 provider（取得目前鏈別）。
///   - 用 `ref.read(...)` 呼叫動作（切鏈、刷新餘額）。
/// ---------------------------------------------------------------------------
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) 監聽目前選中的鏈別（例如：EVM 的 Ethereum / BSC；或是 Solana）。
    final chain = ref.watch(currentChainProvider);

    return Row(
      children: [
        // DropdownButtonHideUnderline：把下拉選單底線藏起來，視覺更乾淨
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            // 2) 將目前鏈別的 id 當成下拉選單的 value
            value: chain.id,

            // 3) 產生清單項目：把 supportedChains（你支援的所有鏈）列出來
            items: [
              for (final c in supportedChains)
                DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      // 不同鏈別顯示不同 icon（純視覺）
                      Icon(
                        c.kind == ChainKind.evm
                            ? Icons.hexagon_outlined
                            : Icons.token_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(c.name), // 顯示鏈名（例如：Sepolia、Devnet）
                    ],
                  ),
                ),
            ],

            // 4) 當使用者從下拉選單選擇了新鏈別
            onChanged: (id) {
              if (id == null) return; // 保護：沒有選到就不做事

              // (A) 切換鏈別：直接把 currentChainIdProvider 的 state 改成新的 id
              //     這會讓依賴這個 provider 的 UI / 邏輯重新計算
              ref.read(currentChainIdProvider.notifier).state = id;

              // (B) 讓跟帳號相關的 provider 重新計算（避免沿用舊鏈的快取）
              ref.invalidate(accountsListProvider);
              ref.invalidate(currentAccountIndexProvider);
              ref.invalidate(currentAccountNameProvider);

              // (C) 非阻塞地刷新餘額（不必等待完成，UI 先更新其他部分）
              unawaited(ref.read(walletProvider.notifier).refreshBalance());

              // (D) 給使用者一個提示訊息（SnackBar）
              final name = supportedChains.firstWhere((e) => e.id == id).name;


              if (!context.mounted) return; // 若畫面已被關閉就不要再顯示
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('已切換到 $name')));
            },
          ),
        ),

        // Spacer：把右邊空間撐開（目前沒有其他按鈕時，讓下拉靠左）
        const Spacer(),
      ],
    );
  }
}

/*
【延伸說明（進階，非必要）】
1) 為什麼這裡可以直接用 ref？
   - onChanged 是同步的，切鏈（改 state）、invalidate、refreshBalance 的呼叫立刻觸發，
     不會跨 await 後才使用 ref，所以不會遇到 "ref disposed" 的問題。

2) 如果你未來在這裡加入了『需要 await』的流程（例如先去打 API 再切鏈），
   建議做法：
   - 先取容器：`final container = ProviderScope.containerOf(context, listen:false);`
   - 將 `invalidate/refresh` 改用 `container` 來呼叫（不受 widget 生命週期影響）。
   - 需要顯示 SnackBar 之前，務必 `if (!context.mounted) return;`。

3) invalidate vs refresh：
   - `invalidate`：標記「過期」，等下次被讀取時才會重算。
   - `refresh`：立即重算並回傳新結果（對 `FutureProvider` 可用 `.future` 來 await）。
   這支 TopBar 用 `invalidate` 就足夠，因為切鏈後下游 UI 會馬上重建並重新讀取。
*/
