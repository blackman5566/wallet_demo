import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

/// Web3Service（EVM RPC 強韌封裝）
///
/// 職責：
/// - 對外提供一個「單一入口」呼叫 RPC：所有讀/寫鏈操作都包在 `run(...)`
/// - `run(...)` 內建：逾時、重試（指數退避 + 抖動）、多端點備援、簡易熔斷
/// - 如果當前端點連續失敗，會短暫冷卻並在後續嘗試自動輪替到備援端點
///
/// 使用建議：
/// - **上層請用封裝好的便捷方法**（或自行包 `run((c) => ...)`），避免直接用 `client.xxx`，
///   這樣才能吃到重試/備援/熔斷的保護。
class Web3Service {
  /// RPC 端點清單。`rpcs[0]` 視為主端點，其餘為備援。
  final List<String> rpcs;

  /// 鏈 ID（送交易時要帶進 `sendTransaction(..., chainId: ...)`）
  final int chainId;

  /// 每「一次嘗試」的逾時（不是整體重試序列的總逾時）
  final Duration callTimeout;

  /// 每個操作最多嘗試次數（包含第一次）。例如 3 代表最多重試 2 次。
  final int maxAttempts;

  /// 指數退避的「基準時間」。實際延遲 = `baseBackoff * 2^tryNo + 隨機抖動`
  final Duration baseBackoff;

  /// 簡易熔斷：當某端點連續失敗達門檻（此處為 2 次）時，會冷卻 `cooldown` 時間不參與輪詢
  final Duration cooldown;

  /// 共享的 HTTP client（節省 TCP/TLS 建立成本）
  late final http.Client _http;

  /// 目前指向的 Web3Client（由 `_idx` 選擇哪個 RPC）
  late Web3Client _client;

  /// 當前使用的 RPC 端點索引（指向 `rpcs[_idx]`）
  int _idx = 0;

  /// 各端點的連續失敗次數（key: 端點索引）
  final Map<int, int> _failCount = {};

  /// 各端點的冷卻截止時間（key: 端點索引）
  final Map<int, DateTime> _coolingUntil = {};

  Web3Service({
    required this.rpcs,
    required this.chainId,
    this.callTimeout = const Duration(seconds: 8),
    this.maxAttempts = 3,
    this.baseBackoff = const Duration(milliseconds: 300),
    this.cooldown = const Duration(seconds: 8),
  }) : assert(rpcs.isNotEmpty, 'rpcs cannot be empty') {
    // 初始化底層 HTTP 與 Web3 client（連到主端點）
    _http = http.Client();
    _client = Web3Client(rpcs[_idx], _http);
  }

  /// 關閉底層資源（App/頁面結束時記得呼叫）
  void dispose() {
    _client.dispose();
    _http.close();
  }

  /// 直接存取底層 client（**除非特殊需求**，平常請優先走 run(...)）
  Web3Client get client => _client;

  // ──────────────────────────────────────────────────────────────────────────
  // Retry / Fallback 核心（所有 RPC 應包在這裡）
  // ──────────────────────────────────────────────────────────────────────────

  /// 將一個 RPC 操作包裝成「逾時 + 重試 + 備援 + 熔斷」的流程。
  ///
  /// - [work]：實際要對鏈執行的動作，例如 `(c) => c.getBalance(addr)`
  /// - [attempts]：覆寫預設最大嘗試數（不傳則用 [maxAttempts]）
  /// - [timeout]：覆寫單次呼叫逾時（不傳則用 [callTimeout]）
  ///
  /// 流程摘要：
  /// 1) 若目前端點在冷卻 → 先輪到下一個端點
  /// 2) 執行 `work(_client).timeout(to)`：
  ///    - 成功：清空該端點失敗次數並回傳
  ///    - 失敗：記錄失敗；若連續失敗≥2 → 設冷卻時間；輪到下一端點；指數退避後重試
  /// 3) 全部嘗試仍失敗 → 丟出最後一次錯誤
  Future<T> run<T>(
      Future<T> Function(Web3Client c) work, {
        int? attempts,
        Duration? timeout,
      }) async {
    final total = attempts ?? maxAttempts;
    final to = timeout ?? callTimeout;

    Object? lastErr;
    for (var tryNo = 0; tryNo < total; tryNo++) {
      // 若目前端點在冷卻中，先輪下一個
      if (_isCooling(_idx)) {
        _rotate();
      }

      try {
        // 執行真正的 RPC 呼叫，並套用單次逾時
        final res = await work(_client).timeout(to);

        // 成功：重置該端點的連續失敗次數
        _failCount[_idx] = 0;
        return res;
      } catch (e) {
        lastErr = e;

        // 失敗：累加該端點失敗次數
        final fc = (_failCount[_idx] ?? 0) + 1;
        _failCount[_idx] = fc;

        // 簡易熔斷：同一端點連續失敗達 2 次 → 設冷卻時間
        if (fc >= 2) {
          _coolingUntil[_idx] = DateTime.now().add(cooldown);
        }

        // 立即輪到下一個端點（即便後續還會退避）
        _rotate();

        // 指數退避 + 抖動，避免「同時多客戶端」一起打爆節點
        final delay = _backoff(tryNo);
        await Future<void>.delayed(delay);
      }
    }

    // 用最後一次錯誤（若沒有就丟一個 generic 的）
    throw lastErr ?? StateError('RPC failed with unknown error');
  }

  /// 當前端點是否在冷卻時間內
  bool _isCooling(int i) {
    final until = _coolingUntil[i];
    return until != null && DateTime.now().isBefore(until);
  }

  /// 切換到下一個端點：
  /// - 優先挑選「沒有在冷卻中的端點」
  /// - 若全部都在冷卻，仍然切到下一個（避免完全卡死）
  /// - 切換時會重建 `_client`，但共用同一個 `_http` 以節省連線成本
  void _rotate() {
    if (rpcs.length == 1) return;

    // 在 rpcs 裡從下一個開始找，直到找到未冷卻的端點
    for (var step = 1; step <= rpcs.length; step++) {
      final next = (_idx + step) % rpcs.length;
      if (!_isCooling(next)) {
        _idx = next;
        _client.dispose();
        _client = Web3Client(rpcs[_idx], _http);
        return;
      }
    }

    // 如果全部都在冷卻，仍然切到下一個（期待冷卻期結束或下一輪重試成功）
    _idx = (_idx + 1) % rpcs.length;
    _client.dispose();
    _client = Web3Client(rpcs[_idx], _http);
  }

  /// 指數退避 + 隨機抖動
  ///
  /// `delay = baseBackoff * (2^tryNo) + jitter(0~180ms)`
  /// - 指數退避避免「持續高頻打擾不穩定端點」
  /// - 抖動可避免多個 client 在同一時刻一起重試造成尖峰
  Duration _backoff(int tryNo) {
    final pow2 = 1 << tryNo;                // 1, 2, 4, ...
    final jitterMs = Random().nextInt(180); // 0~180ms
    return baseBackoff * pow2 + Duration(milliseconds: jitterMs);
  }
}


// ──────────────────────────────────────────────────────────────────────────
// Extension：把「便捷 RPC 與工具」集中在這裡（皆走 run(...)）
// ──────────────────────────────────────────────────────────────────────────
extension Web3ServiceRpc on Web3Service {
  /// 取得帳號的交易次數（nonce），預設取 pending
  Future<int> getTransactionCount(
      EthereumAddress addr, {
        BlockNum atBlock = const BlockNum.pending(),
      }) =>
      run((c) => c.getTransactionCount(addr, atBlock: atBlock));

  /// 最新區塊號
  Future<int> getBlockNumber() => run((c) => c.getBlockNumber());

  /// 以 tx hash 取交易資訊
  Future<TransactionInformation?> getTransactionByHash(String hash) =>
      run((c) => c.getTransactionByHash(hash));

  /// 以 tx hash 取收據
  Future<TransactionReceipt?> getTransactionReceipt(String hash) =>
      run((c) => c.getTransactionReceipt(hash));

  /// 帳戶餘額
  Future<EtherAmount> getBalance(EthereumAddress addr) =>
      run((c) => c.getBalance(addr));

  /// 建議 gasPrice（legacy）
  Future<EtherAmount> getGasPrice() => run((c) => c.getGasPrice());


  /// 估算 gas
  Future<BigInt> estimateGas({
    required EthereumAddress from,
    EthereumAddress? to,
    EtherAmount? value,
    Uint8List? data,
  }) =>
      run((c) => c.estimateGas(
        sender: from,
        to: to,
        value: value,
        data: data,
      ));

  /// 寄送交易（自動帶 chainId）
  Future<String> sendTx(Credentials creds, Transaction tx) =>
      run((c) => c.sendTransaction(creds, tx, chainId: chainId));

  /// Utils：私鑰→地址/憑證（不打 RPC）
  EthereumAddress addressFromPrivHex(String privHex) =>
      EthPrivateKey.fromHex(privHex).address;

  Credentials credentialsFromHex(String privHex) =>
      EthPrivateKey.fromHex(privHex);

  /// （可選）WS newHeads 流：若底層 client 為 WS 連線可直接使用
  Stream<dynamic> newHeadsStream() => client.addedBlocks();
}
