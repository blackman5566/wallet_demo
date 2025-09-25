// 引入 web3dart，用於與以太坊 RPC 溝通
import 'package:web3dart/web3dart.dart';

enum GasUrgency {
  slow,      // 省錢為主：可以等比較久，費率最低
  standard,  // 預設：在速度與成本之間取得平衡
  fast,      // 快速：願意多付一點費率，加快被打包的機率
  instant    // 立即：最高費率，力求最快上鏈（適用極度急迫的情況）
}

/// ===========================================================================
/// 封裝「EIP-1559 交易手續費建議值」的資料類別
/// ===========================================================================
/// sendTransaction 需要的兩個關鍵參數：
/// 1. maxFeePerGas         : 交易願意支付的 **最大 Gas 單價**
///                           = (下一區塊 baseFee × 倍數) + tip
/// 2. maxPriorityFeePerGas : 礦工小費 (tip)
/// ---------------------------------------------------------------------------
/// 這個類別就是把兩個值綁在一起，方便外部直接使用。
class Eip1559FeeSuggestion {
  final EtherAmount maxFeePerGas;          // 最大願付單價 (包含 baseFee + tip)
  final EtherAmount maxPriorityFeePerGas;  // 小費 (tip)
  const Eip1559FeeSuggestion({
    required this.maxFeePerGas,
    required this.maxPriorityFeePerGas,
  });
}

/// ===========================================================================
/// 私有策略函式：根據「交易急迫度」決定計算參數
/// ===========================================================================
/// 回傳一個 record，包含：
/// - lookback         : 要觀察的歷史區塊數量（越急迫看越少）
/// - baseFeeMultiplier: 下一區塊 baseFee 的放大倍率 (越急迫越大)
/// - fallbackTipGwei  : 如果 RPC 沒回傳 reward 時的小費預設值 (gwei)
({int lookback, int baseFeeMultiplier, int fallbackTipGwei}) _policy(GasUrgency l) {
  switch (l) {
    case GasUrgency.slow:
    // 低急迫：看最近 10 個區塊，安全係數 2 倍，小費預設 1 gwei
      return (lookback: 10, baseFeeMultiplier: 2, fallbackTipGwei: 1);
    case GasUrgency.standard:
    // 一般：看 5 個區塊，安全係數 2 倍，小費預設 2 gwei
      return (lookback: 5,  baseFeeMultiplier: 2, fallbackTipGwei: 2);
    case GasUrgency.fast:
    // 快速：看 4 個區塊，安全係數 3 倍，小費預設 3 gwei
      return (lookback: 4,  baseFeeMultiplier: 3, fallbackTipGwei: 3);
    case GasUrgency.instant:
    // 立刻：看 3 個區塊，安全係數 4 倍，小費預設 5 gwei
      return (lookback: 3,  baseFeeMultiplier: 4, fallbackTipGwei: 5);
  }
}

/// ===========================================================================
/// 主要函式：計算 EIP-1559 建議手續費
/// ===========================================================================
/// [client] : 已建立好的 web3dart Web3Client 連線
/// [level]  : 使用者指定的急迫度（預設 standard）
///
/// 演算法步驟：
/// 1️⃣ 依急迫度取得策略 (lookback, baseFeeMultiplier, fallbackTipGwei)
/// 2️⃣ 呼叫 RPC `eth_feeHistory` 取最近 N 個區塊的 baseFee 與 reward
/// 3️⃣ 取下一個區塊的 baseFee (baseFeeNext)
/// 4️⃣ 取得最近區塊的 50% 分位 priority fee 作為 tip
///    - 若 reward 資料缺失或為 0，使用 fallbackTipGwei
/// 5️⃣ 計算 maxFee = baseFeeNext × baseFeeMultiplier + tip
/// 6️⃣ 回傳 Eip1559FeeSuggestion 給外部使用
Future<Eip1559FeeSuggestion> suggestEip1559Fees(
    Web3Client client, {
      GasUrgency level = GasUrgency.standard,
    }) async {

  // 1️⃣ 依照急迫度取得對應策略
  final p = _policy(level);

  // 2️⃣ 向鏈上請求 feeHistory
  //    - p.lookback   : 觀察的區塊數
  //    - atBlock      : 以最新區塊為基準
  //    - rewardPercentiles: 希望返回 priority fee 的統計分位數
  final hist = await client.getFeeHistory(
    p.lookback,
    atBlock: const BlockNum.current(),
    rewardPercentiles: const [10, 25, 50, 75, 90],
  );

  // 小工具：把 0x 開頭的十六進位字串轉成 EtherAmount(wei)
  EtherAmount _weiHex(dynamic hex) {
    final s = hex as String;
    final bi = BigInt.parse(
      s.startsWith('0x') ? s.substring(2) : s,
      radix: 16,
    );
    return EtherAmount.inWei(bi);
  }

  // 3️⃣ 取下一區塊的 baseFee
  final baseFees = (hist['baseFeePerGas'] as List);
  if (baseFees.isEmpty) {
    // 沒有 baseFee 資料就直接報錯
    throw StateError('feeHistory: baseFeePerGas missing');
  }
  final baseFeeNext = _weiHex(baseFees.last); // 取最後一筆 = 下一區塊

  // 4️⃣ 計算 tip（priority fee）
  final gwei = BigInt.from(1000000000); // 1 gwei = 10^9 wei
  EtherAmount tip;
  try {
    // 取最近區塊的 reward
    final rewards = hist['reward'] as List?;
    if (rewards == null || rewards.isEmpty) {
      throw StateError('feeHistory: reward missing');
    }
    final last = rewards.last as List;   // 最近一個區塊的所有分位數
    // percentiles = [10,25,50,75,90] → 50% 分位在 index=2
    tip = _weiHex(last[2]);
    // 如果 50% 分位是 0，使用 fallbackTipGwei
    if (tip.getInWei == BigInt.zero) {
      tip = EtherAmount.inWei(BigInt.from(p.fallbackTipGwei) * gwei);
    }
  } catch (_) {
    // RPC 沒回傳 reward 或解析失敗，一律用 fallback
    tip = EtherAmount.inWei(BigInt.from(p.fallbackTipGwei) * gwei);
  }

  // 5️⃣ 計算最大願付 Gas 單價
  //     maxFee = baseFeeNext * baseFeeMultiplier + tip
  final maxFee = EtherAmount.inWei(
    baseFeeNext.getInWei * BigInt.from(p.baseFeeMultiplier) + tip.getInWei,
  );

  // 6️⃣ 回傳建議結果
  return Eip1559FeeSuggestion(
    maxFeePerGas: maxFee,
    maxPriorityFeePerGas: tip,
  );
}
