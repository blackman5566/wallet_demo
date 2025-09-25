import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  final String rpcUrl; // 區塊鏈節點的 RPC URL
  final int chainId;   // 區塊鏈 Chain ID（EVM 交易需要）

  // 私有建構子：外部不能直接 new，只能透過 Env._ 內部使用
  Env._(this.rpcUrl, this.chainId);

  /// 先給一個預設值，避免 App 啟動時還沒讀到 .env 就報 late 初始化錯誤。
  /// 預設是 Ethereum Sepolia 測試網。
  static Env instance =
  Env._('https://ethereum-sepolia-rpc.publicnode.com', 11155111);

  /// 在 App 啟動時呼叫，讀取 .env 檔，覆寫預設值
  static Future<void> load() async {
    try {
      // 嘗試載入環境變數檔
      // 如果 .env 檔放在 assets/env/.env，需要在 pubspec.yaml 的 assets 列表中聲明
      await dotenv.load(fileName: 'assets/env/.env');
    } catch (_) {
      // 如果檔案不存在或讀取失敗，直接忽略
      // 不要因為缺檔讓 App crash
    }

    // 讀取環境變數
    // 讀不到就回退到當前 instance 的值（即預設）
    final rpc = dotenv.env['RPC_URL'] ?? instance.rpcUrl;
    final id  = int.tryParse(
      dotenv.env['CHAIN_ID'] ?? '${instance.chainId}',
    ) ?? instance.chainId;

    // 更新單例
    instance = Env._(rpc, id);
  }
}
