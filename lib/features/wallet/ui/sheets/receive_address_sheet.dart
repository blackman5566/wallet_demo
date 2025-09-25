import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ---------------------------------------------------------------------------
/// ReceiveAddressSheet（接收地址的 BottomSheet）
///
/// 功能：
/// - 顯示當前錢包的地址，讓使用者可以複製。
/// - 使用 `SelectableText` 方便長按選取與複製。
/// - 提供「複製地址」按鈕：點擊後會將地址複製到剪貼簿，並提示成功訊息。
///
/// 為什麼用 StatelessWidget？
/// - 這個面板不需要本地狀態（沒有 TextEditingController、沒有要改變的值）。
/// - address 是由父層傳入的 final 參數，所以只要 StatelessWidget 就足夠。
/// ---------------------------------------------------------------------------
class ReceiveAddressSheet extends StatelessWidget {
  const ReceiveAddressSheet({super.key, required this.address});

  /// 外部傳入的錢包地址
  final String address;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 高度跟隨內容，不會撐滿整個螢幕
        children: [
          // 標題
          Text('Receive address', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),

          // 可選取的文字，方便複製完整地址
          SelectableText(address),
          const SizedBox(height: 12),

          // 複製按鈕
          FilledButton.icon(
            onPressed: () async {
              // 把地址寫進剪貼簿
              await Clipboard.setData(ClipboardData(text: address));

              if (!context.mounted) return; // 若畫面已被卸載就不繼續操作

              // 關閉 BottomSheet
              Navigator.pop(context);

              // 顯示提示訊息
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Copyed address')));
            },
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('Copy address'),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
