import 'dart:async';
import 'dart:math';
import 'package:solana/dto.dart' as sol;
import 'package:solana/solana.dart' as sol;

/// SolRpcService（Solana RPC 強韌封裝）
/// - 單一入口 run(...)：逾時 / 重試（指數退避 + 抖動）/ 多端點備援 / 簡易熔斷
/// - 建議只透過底下的便捷方法呼叫，不要直接用 client.xxx
class SolRpcService {
  /// RPC 端點清單（rpcs[0] 為主端點，其餘為備援）
  final List<String> rpcs;

  /// 單次嘗試的逾時
  final Duration callTimeout;

  /// 最大嘗試次數（含第一次）
  final int maxAttempts;

  /// 指數退避基準
  final Duration baseBackoff;

  /// 熔斷冷卻時間
  final Duration cooldown;

  /// 查詢確認層級
  final sol.Commitment commitment;

  /// 目前指向的 RpcClient（由 _idx 決定）
  late sol.RpcClient _client;

  /// 目前使用的 RPC 端點索引
  int _idx = 0;

  /// 各端點連續失敗次數
  final Map<int, int> _failCount = {};

  /// 各端點冷卻截止時間
  final Map<int, DateTime> _coolingUntil = {};

  SolRpcService({
    required this.rpcs,
    this.callTimeout = const Duration(seconds: 8),
    this.maxAttempts = 3,
    this.baseBackoff = const Duration(milliseconds: 300),
    this.cooldown = const Duration(seconds: 8),
    this.commitment = sol.Commitment.confirmed,
  }) : assert(rpcs.isNotEmpty, 'rpcs cannot be empty') {
    _client = sol.RpcClient(rpcs[_idx], timeout: callTimeout);
  }

  /// 直接取底層 client（一般請優先走 run(...)）
  sol.RpcClient get client => _client;

  // ──────────────────────────────────────────────────────────────────────────
  // Retry / Fallback 核心
  // ──────────────────────────────────────────────────────────────────────────
  Future<T> run<T>(
      Future<T> Function(sol.RpcClient c) work, {
        int? attempts,
        Duration? timeout,
      }) async {
    final total = attempts ?? maxAttempts;
    final to = timeout ?? callTimeout;

    Object? lastErr;
    for (var tryNo = 0; tryNo < total; tryNo++) {
      if (_isCooling(_idx)) _rotate();

      try {
        final res = await work(_client).timeout(to);
        _failCount[_idx] = 0; // 成功：清零
        return res;
      } catch (e) {
        lastErr = e;

        final fc = (_failCount[_idx] ?? 0) + 1;
        _failCount[_idx] = fc;

        if (fc >= 2) {
          _coolingUntil[_idx] = DateTime.now().add(cooldown);
        }

        _rotate();
        await Future<void>.delayed(_backoff(tryNo));
      }
    }
    throw lastErr ?? StateError('Solana RPC failed with unknown error');
  }

  bool _isCooling(int i) {
    final until = _coolingUntil[i];
    return until != null && DateTime.now().isBefore(until);
  }

  void _rotate() {
    if (rpcs.length == 1) return;

    for (var step = 1; step <= rpcs.length; step++) {
      final next = (_idx + step) % rpcs.length;
      if (!_isCooling(next)) {
        _idx = next;
        _client = sol.RpcClient(rpcs[_idx], timeout: callTimeout);
        return;
      }
    }

    _idx = (_idx + 1) % rpcs.length;
    _client = sol.RpcClient(rpcs[_idx], timeout: callTimeout);
  }

  Duration _backoff(int tryNo) {
    final pow2 = 1 << tryNo;                // 1, 2, 4, ...
    final jitterMs = Random().nextInt(180); // 0~180ms
    return baseBackoff * pow2 + Duration(milliseconds: jitterMs);
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Extension：便捷 RPC 與工具（皆走 run(...)）
// ──────────────────────────────────────────────────────────────────────────
extension SolRpcServiceRpc on SolRpcService {
  /// 取得 lamports（1 SOL = 1e9 lamports）
  Future<int> getBalance(String address) async {
    final res = await run((c) => c.getBalance(address, commitment: commitment));
    return res.value; // BalanceResult.value -> int
  }

  /// 取得最新 blockhash（轉帳/簽名常用）
  Future<sol.LatestBlockhash> getLatestBlockhash() async {
    final res = await run((c) => c.getLatestBlockhash(commitment: commitment));
    return res.value;
  }

  /// 查詢交易狀態（回第一筆狀態）
  Future<sol.SignatureStatus?> getSignatureStatus(String signature) async {
    final res = await run(
          (c) => c.getSignatureStatuses([signature], searchTransactionHistory: true),
    ); // SignatureStatusesResult
    return res.value.isNotEmpty ? res.value.first : null;
  }

  /// 等待 Finalized（簡化輪詢）
  Future<void> waitFinalized(
      String signature, {
        Duration pollInterval = const Duration(seconds: 1),
        Duration timeout = const Duration(seconds: 30),
      }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final st = await getSignatureStatus(signature);
      if (st?.confirmationStatus == sol.Commitment.finalized) return;
      await Future<void>.delayed(pollInterval);
    }
    throw TimeoutException('Wait finalized timeout');
  }

  /// 便捷「原生 SOL 轉帳」
  Future<String> transfer({
    required sol.Ed25519HDKeyPair from,
    required String toAddress, // base58
    required int lamports,
  }) async {
    final to = sol.Ed25519HDPublicKey.fromBase58(toAddress);

    final ix = sol.SystemInstruction.transfer(
      fundingAccount: from.publicKey,
      recipientAccount: to,
      lamports: lamports,
    );

    // 用 solana 的 Message（會走 v0/legacy 自動處理）
    final msg = sol.Message(instructions: [ix]);

    // 直接簽名 + 送出（RpcClient 的 extension）
    final txId = await run(
          (c) => c.signAndSendTransaction(
        msg,
        [from],
        commitment: commitment,
      ),
    );

    return txId; // TransactionId (String)
  }

  /// Utils：keypair → base58 地址（不打 RPC）
  String addressFromKeypair(sol.Ed25519HDKeyPair kp) => kp.address;
}
