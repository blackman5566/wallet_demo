import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart';

/// ---------- 型別 ----------

class PendingTx {
  final String addr;      // EIP-55 address字串
  final BigInt nonce;     // 以 BigInt 存比較安全
  final String txHash;
  final int chainId;
  final DateTime insertedAt;
  final String? rawTx;    // 可選：保留 rawTx 以便重播或偵錯

  const PendingTx({
    required this.addr,
    required this.nonce,
    required this.txHash,
    required this.chainId,
    required this.insertedAt,
    this.rawTx,
  });

  Map<String, dynamic> toJson() => {
    'addr': addr,
    'nonce': nonce.toString(),
    'txHash': txHash,
    'chainId': chainId,
    'insertedAt': insertedAt.toIso8601String(),
    'rawTx': rawTx,
  };

  static PendingTx fromJson(Map<String, dynamic> j) => PendingTx(
    addr: j['addr'] as String,
    nonce: BigInt.parse(j['nonce'] as String),
    txHash: j['txHash'] as String,
    chainId: j['chainId'] as int,
    insertedAt: DateTime.parse(j['insertedAt'] as String),
    rawTx: j['rawTx'] as String?,
  );
}

/// ---------- 介面 ----------

abstract class NonceStore {
  /// 取得下一個「安全」nonce
  Future<BigInt> nextNonce(EthereumAddress addr, Web3Client client);

  /// 新送出（或替換）交易加入本地 pending 佇列
  Future<void> enqueue(PendingTx tx);

  /// 最終落塊/被替換/失敗 → 從本地移除
  Future<void> resolve(String addr, int chainId, BigInt nonce);

  /// 列出目前本地 pending（供開機恢復用）
  Future<List<PendingTx>> list(String addr, int chainId);
}

/// ---------- 簡單實作（用 flutter_secure_storage） ----------

class SecureNonceStore implements NonceStore {
  final FlutterSecureStorage storage;
  SecureNonceStore(this.storage);

  String _key(String addr, int chainId) => 'pending:$chainId:$addr';

  @override
  Future<BigInt> nextNonce(EthereumAddress addr, Web3Client client) async {
    // 注意：不同 web3dart 版本回傳型別不同，這裡都轉成 BigInt 來比
    final int onchainInt = await client.getTransactionCount(
      addr,
      atBlock: BlockNum.pending(), // 某些版本不支援 const，別加 const
    );
    final dynamic cidAny = await client.getChainId();
    final int chainId = cidAny is BigInt ? cidAny.toInt() : cidAny as int;

    final pending = await list(addr.hexEip55, chainId);

    final BigInt localMax = pending.isEmpty
        ? BigInt.from(-1)
        : pending.map((e) => e.nonce).reduce((a, b) => a > b ? a : b);

    final BigInt onchain = BigInt.from(onchainInt);

    // 安全選擇：鏈上（含 pending） vs 本地最大+1，取較大者
    final BigInt next = onchain > localMax ? onchain : localMax + BigInt.one;
    return next;
  }

  @override
  Future<void> enqueue(PendingTx tx) async {
    final key = _key(tx.addr, tx.chainId);
    final raw = await storage.read(key: key);
    final list = raw == null
        ? <PendingTx>[]
        : (jsonDecode(raw) as List)
        .map((e) => PendingTx.fromJson(e as Map<String, dynamic>))
        .toList();

    // 同一個 nonce 只保留最新那筆（避免殘留舊的）
    final filtered = list.where((e) => e.nonce != tx.nonce).toList()..add(tx);
    await storage.write(
      key: key,
      value: jsonEncode(filtered.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<void> resolve(String addr, int chainId, BigInt nonce) async {
    final key = _key(addr, chainId);
    final raw = await storage.read(key: key);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => PendingTx.fromJson(e as Map<String, dynamic>))
        .toList();
    final filtered = list.where((e) => e.nonce != nonce).toList();
    await storage.write(
      key: key,
      value: jsonEncode(filtered.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<PendingTx>> list(String addr, int chainId) async {
    final key = _key(addr, chainId);
    final raw = await storage.read(key: key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => PendingTx.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
