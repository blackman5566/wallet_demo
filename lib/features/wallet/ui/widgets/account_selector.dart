import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_demo/features/wallet/data/providers/wallet_providers.dart';

import '../../data/providers/wallet_notifier.dart';

/// ---------------------------------------------------------------------------
/// AccountSelector（帳號選擇器）
/// - 用來顯示使用者的錢包帳號列表，並支援：
///   1) 當前帳號下拉選擇。
///   2) 新增帳號。
///   3) 手動刷新餘額。
/// - 使用 ConsumerWidget：
///   - 可以直接拿到 ref（Riverpod 提供的物件），在 build 時讀取/監聽 provider 狀態。
/// ---------------------------------------------------------------------------
class AccountSelector extends ConsumerWidget {
  const AccountSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // st = 整體錢包狀態（裡面可能有餘額、忙碌中等）
    final st = ref.watch(walletProvider);
    // accountsAsync = 非同步取得帳號列表（可能在載入中、錯誤、或拿到資料）
    final accountsAsync = ref.watch(accountsListProvider);
    // currentIdxAsync = 當前選中的帳號 index
    final currentIdxAsync = ref.watch(currentAccountIndexProvider);

    return accountsAsync.when(
      loading: () => const SizedBox.shrink(), // 資料還在載入 → 回傳空容器
      error: (e, _) => Text('Load accounts failed：$e'),
      data: (list) {
        // 如果完全沒有帳號 → 顯示「尚無帳號」＋一個新增按鈕
        if (list.isEmpty) {
          return Row(
            children: [
              Text('No accounts', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: st.busy
                    ? null // 忙碌中就禁用
                    : () async {
                  // ⚠️ 使用 container 而不是 ref，避免 widget dispose 時 ref 出錯
                  final container =
                  ProviderScope.containerOf(context, listen: false);
                  final notifier = ref.read(walletProvider.notifier);

                  await notifier.createAccountNext(); // 建立新帳號

                  // 立刻刷新 provider，讓 UI 即時更新
                  await container.refresh(accountsListProvider.future);
                  await container.refresh(currentAccountIndexProvider.future);
                  container.invalidate(currentAccountNameProvider);

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added accounts')),
                  );
                },
                icon: st.busy
                    ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.add),
                label: const Text('Add accounts'),
              ),
            ],
          );
        }

        // 有帳號時 → 算出目前 index（若異常則用最後一個帳號兜底）
        var currentIdx = currentIdxAsync.maybeWhen(
          data: (v) => v,
          orElse: () => list.last.index,
        );
        final minIdx = list.first.index;
        final maxIdx = list.last.index;
        if (currentIdx < minIdx) currentIdx = minIdx;
        if (currentIdx > maxIdx) currentIdx = maxIdx;

        // 回傳帳號選擇器 UI
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 下拉選單：讓使用者切換帳號
                IgnorePointer(
                  ignoring: st.busy, // 忙碌中暫時無法操作
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: currentIdx,
                      items: [
                        for (final a in list)
                          DropdownMenuItem(
                            value: a.index,
                            child: Text(
                              a.name.isEmpty
                                  ? 'Account ${a.index + 1}'
                                  : a.name,
                            ),
                          ),
                      ],
                      onChanged: st.busy
                          ? null
                          : (v) async {
                        if (v == null) return;

                        final container = ProviderScope.containerOf(
                            context,
                            listen: false);
                        final notifier =
                        ref.read(walletProvider.notifier);

                        await notifier.selectAccount(v);

                        // 刷新目前索引/名稱
                        await container.refresh(
                            currentAccountIndexProvider.future);
                        container.invalidate(
                            currentAccountNameProvider);

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                              Text('Switched account ${v + 1}')),
                        );
                      },
                    ),
                  ),
                ),

                // 新增帳號按鈕（與前面「完全沒帳號」時相同邏輯）
                FilledButton.icon(
                  onPressed: st.busy
                      ? null
                      : () async {
                    final container = ProviderScope.containerOf(
                        context,
                        listen: false);
                    final notifier =
                    ref.read(walletProvider.notifier);

                    await notifier.createAccountNext();

                    await container.refresh(accountsListProvider.future);
                    await container
                        .refresh(currentAccountIndexProvider.future);
                    container.invalidate(currentAccountNameProvider);

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account added')),
                    );
                  },
                  icon: st.busy
                      ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.add),
                  label: const Text('Add account'),
                ),

                // 刷新餘額按鈕
                IconButton(
                  tooltip: 'Refresh balance',
                  onPressed: st.busy
                      ? null
                      : () => ref
                      .read(walletProvider.notifier)
                      .refreshBalance(),
                  icon: st.busy
                      ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
