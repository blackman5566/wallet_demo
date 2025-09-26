import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reown_walletkit/reown_walletkit.dart';
import 'package:web3dart/web3dart.dart';

import '../core/common/chains.dart';
import '../core/evm/EIP1559Model/fee_api_web3dart.dart';
import '../core/keyService/core/key_service.dart';
import '../core/keyService/keyServiceProvider.dart';
import '../core/service/evm/nonce_store.dart';
import '../core/service/evm/evm_rpc_service.dart';
import '../providers/wallet_providers.dart';
import 'chain_client.dart';

// 類別內放一個 NonceStore（你也可以改成從 provider 取得）
final _nonceStore = SecureNonceStore(const FlutterSecureStorage());

class EvmChainClient implements ChainClient {
  EvmChainClient(this.ref);
  final Ref ref;

  EthereumAddress? _addrCache;

  @override
  ChainKind get kind => ChainKind.evm;

  @override
  void clearCache() {
    _addrCache = null;
  }

  @override
  Future<void> setAccountIndex(int i) async {
    await ref.read(keyServiceProvider).setIndexByKind(ChainKind.evm, i);
    clearCache();
  }

  @override
  Future<void> addNextAccountAndSelect() async {
    await ref.read(keyServiceProvider).addAccount(ChainKind.evm);
    clearCache();
  }

  @override
  Future<String> getAddress() async {
    if (_addrCache != null) return _addrCache!.hexEip55;
    final ks = ref.read(keyServiceProvider);
    final web3 = ref.read(web3ServiceProvider);
    final privHex = await ks.deriveEvmPrivHex();
    _addrCache = web3.addressFromPrivHex(privHex);
    return _addrCache!.hexEip55;
  }

  @override
  Future<BigInt> getNativeBalance() async {
    final web3 = ref.read(web3ServiceProvider);
    final addr = _addrCache ??
        web3.addressFromPrivHex(
          await ref.read(keyServiceProvider).deriveEvmPrivHex(),
        );
    final bal = await web3.getBalance(addr);
    return bal.getInWei;
  }

  // ---------------------------------------------------------------------------
  // 發送原生幣交易（先試 1559，拿不到 → legacy）
  // ---------------------------------------------------------------------------
  @override
  Future<String> sendNative({
    required String toAddress,
    required BigInt amount,
  }) async {
    final web3 = ref.read(web3ServiceProvider);
    final ks = ref.read(keyServiceProvider);
    final privHex = await ks.deriveEvmPrivHex();
    final creds   = web3.credentialsFromHex(privHex);
    final from    = web3.addressFromPrivHex(privHex);
    final to      = EthereumAddress.fromHex(toAddress);

    // 取得 chainId
    int chainId;
    try {
      chainId = (web3 as dynamic).chainId as int;
    } catch (_) {
      final cidAny = await web3.client.getChainId();
      chainId = cidAny is BigInt ? cidAny.toInt() : cidAny as int;
    }

    // 估 gasLimit + buffer
    final gasLimit = await _estimateGasWithBuffer(
      web3: web3,
      from: from,
      to: to,
      value: EtherAmount.inWei(amount),
      data: null,
    );

    // 安全 nonce
    final BigInt safeNonce = await _nonceStore.nextNonce(from, web3.client);

    // 先嘗試 1559，拿不到就 legacy
    final maybe1559 = await _safeSuggest1559(web3.client, level: GasUrgency.standard);

    if (maybe1559 != null) {
      final (maxFee, maxTip) = maybe1559;

      // print("sendNative nonce = ${safeNonce.toInt()}");

      final tx1559 = Transaction(
        to: to,
        value: EtherAmount.inWei(amount),
        nonce: safeNonce.toInt(),
        maxPriorityFeePerGas: maxTip,
        maxFeePerGas: maxFee,
        maxGas: gasLimit,
      );

      final hash = await web3.sendTx(creds, tx1559);

      await _nonceStore.enqueue(PendingTx(
        addr: from.hexEip55,
        nonce: safeNonce,
        txHash: hash,
        chainId: chainId,
        insertedAt: DateTime.now(),
      ));
      return hash;
    }

    // Legacy fallback
    final gasPrice = await web3.getGasPrice();

    final legacyTx = Transaction(
      to: to,
      value: EtherAmount.inWei(amount),
      nonce: safeNonce.toInt(),
      gasPrice: gasPrice,
      maxGas: gasLimit,
    );

    final hash = await web3.sendTx(creds, legacyTx);

    print("safeNoncesafeNoncesafeNonce 發送的=$safeNonce");
    await _nonceStore.enqueue(PendingTx(
      addr: from.hexEip55,
      nonce: safeNonce,
      txHash: hash,
      chainId: chainId,
      insertedAt: DateTime.now(),
    ));
    return hash;
  }
}

// ---------------------------------------------------------------------------
// 交易加速（優先 1559 → fallback legacy）
// ---------------------------------------------------------------------------
extension EvmChainSpeedUpTx on EvmChainClient {
  Future<String> speedUpByHash(String txHash) async {
    final web3 = ref.read(web3ServiceProvider);
    final ks   = ref.read(keyServiceProvider);

    final info = await web3.client.getTransactionByHash(txHash);
    if (info == null) {
      throw Exception('找不到原交易（可能節點尚未索引或已遺忘）');
    }

    final privHex = await ks.deriveEvmPrivHex();
    final creds   = web3.credentialsFromHex(privHex);
    final from    = web3.addressFromPrivHex(privHex);
    final cidAny  = await web3.client.getChainId();
    final chainId = cidAny is BigInt ? cidAny.toInt() : cidAny as int;

    final nonce = info.nonce;
    final to    = info.to;
    final value = info.value ?? EtherAmount.zero();
    final data  = info.input;
    final gas   = info.gas?.toInt() ?? 21000;

    BigInt _bump(BigInt x) {
      final inc = (x * BigInt.from(125)) ~/ BigInt.from(1000); // +12.5%
      final min = BigInt.from(2e9);                            // +2 gwei
      return (x + inc) > (x + min) ? (x + inc) : (x + min);
    }

    final maybe1559 = await _safeSuggest1559(web3.client, level: GasUrgency.fast);
    if (maybe1559 != null) {
      final (maxFeeBase, maxTipBase) = maybe1559;
      final tx1559 = Transaction(
        to: to,
        value: value,
        nonce: nonce,
        maxGas: gas,
        data: data,
        maxFeePerGas: EtherAmount.inWei(_bump(maxFeeBase.getInWei)),
        maxPriorityFeePerGas: EtherAmount.inWei(_bump(maxTipBase.getInWei)),
      );
      final newHash = await web3.sendTx(creds, tx1559);

      await _nonceStore.enqueue(PendingTx(
        addr: from.hexEip55,
        nonce: BigInt.from(nonce),
        txHash: newHash,
        chainId: chainId,
        insertedAt: DateTime.now(),
      ));
      return newHash;
    }

    // legacy bump
    final gp = await web3.client.getGasPrice();
    final bumped = EtherAmount.inWei(_bump(gp.getInWei));
    final legacyTx = Transaction(
      to: to,
      value: value,
      nonce: nonce,
      gasPrice: bumped,
      maxGas: gas,
      data: data,
    );
    final newHash = await web3.sendTx(creds, legacyTx);

    await _nonceStore.enqueue(PendingTx(
      addr: from.hexEip55,
      nonce: BigInt.from(nonce),
      txHash: newHash,
      chainId: chainId,
      insertedAt: DateTime.now(),
    ));
    return newHash;
  }
}

// ---------------------------------------------------------------------------
// 取消
//  - EOA：對自己轉 0（nonce 相同、費率更高）
//  - 合約錢包：改做「加速替代」而非自轉 0（避免 revert）
// ---------------------------------------------------------------------------
extension EvmChainCancelTx on EvmChainClient {
  Future<String> cancelByHash(String txHash) async {
    final web3  = ref.read(web3ServiceProvider);
    final ks    = ref.read(keyServiceProvider);

    final info = await web3.client.getTransactionByHash(txHash);
    if (info == null) {
      throw Exception('找不到原交易（可能節點尚未索引或已被替換/遺忘）');
    }

    final privHex = await ks.deriveEvmPrivHex();
    final creds   = web3.credentialsFromHex(privHex);
    final from    = web3.addressFromPrivHex(privHex);

    final cidAny  = await web3.client.getChainId();
    final chainId = cidAny is BigInt ? cidAny.toInt() : (cidAny as int);
    final nonce   = info.nonce;
    BigInt _bumpWei(BigInt x, {double pct = 0.25, BigInt? minBump}) {
      final min = minBump ?? BigInt.from(5000000000); // 至少 +5 gwei
      final inc = (x * BigInt.from((pct * 1000).round())) ~/ BigInt.from(1000);
      final bumped = x + inc;
      final withMin = x + min;
      return bumped > withMin ? bumped : withMin;
    }

    Future<int> _estimateWithBuffer({
      required EthereumAddress to,
      required EtherAmount value,
      Uint8List? data,
      double buffer = 0.25,
    }) async {
      try {
        final est = await web3.client.estimateGas(
          sender: from, to: to, value: value, data: data,
        );
        return (est.toDouble() * (1 + buffer)).ceil();
      } catch (_) {
        return 21000;
      }
    }

      final maybe1559 = await _safeSuggest1559(web3.client, level: GasUrgency.fast);
      if (maybe1559 != null) {
        final (maxFeeBase, maxTipBase) = maybe1559;
        final gasLimit = await _estimateWithBuffer(
          to: from, value: EtherAmount.zero(), data: null,
        );
        final tx1559 = Transaction(
          to: from,
          value: EtherAmount.zero(),
          nonce: nonce,
          maxGas: gasLimit,
          maxFeePerGas: EtherAmount.inWei(_bumpWei(maxFeeBase.getInWei)),
          maxPriorityFeePerGas: EtherAmount.inWei(_bumpWei(maxTipBase.getInWei)),
        );

        final newHash = await web3.sendTx(creds, tx1559);
        await _nonceStore.enqueue(PendingTx(
          addr: from.hexEip55,
          nonce: BigInt.from(nonce),
          txHash: newHash,
          chainId: chainId,
          insertedAt: DateTime.now(),
        ));
        return newHash;
      }

      // legacy
      final gp = await web3.client.getGasPrice();
      final gasPrice = EtherAmount.inWei(_bumpWei(gp.getInWei));
      final gasLimit = await _estimateWithBuffer(
        to: from, value: EtherAmount.zero(), data: null,
      );

      final legacy = Transaction(
        to: from,
        value: EtherAmount.zero(),
        nonce: nonce,
        gasPrice: gasPrice,
        maxGas: gasLimit,
      );

      final newHash = await web3.sendTx(creds, legacy);
      await _nonceStore.enqueue(PendingTx(
        addr: from.hexEip55,
        nonce: BigInt.from(nonce),
        txHash: newHash,
        chainId: chainId,
        insertedAt: DateTime.now(),
      ));
      return newHash;
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
extension EvmChainGasWithBuffer on EvmChainClient {
  /// estimateGas + buffer（失敗回 21000）
  Future<int> _estimateGasWithBuffer({
    required dynamic web3, // Web3Service
    required EthereumAddress from,
    required EthereumAddress? to,
    required EtherAmount value,
    Uint8List? data,
    double buffer = 0.20,
  }) async {
    try {
      final est = await web3.estimateGas(
        from: from,
        to: to,
        value: value,
        data: data,
      );
      final bumped = (est.toDouble() * (1 + buffer)).ceil();
      return bumped;
    } catch (_) {
      return 21000;
    }
  }

  /// 安全拿 1559 建議值；拿不到回 null，呼叫端 fallback legacy
  Future<(EtherAmount maxFee, EtherAmount maxPriorityFee)?> _safeSuggest1559(
      Web3Client client, { GasUrgency level = GasUrgency.standard }
      ) async {
    try {
      final s = await suggestEip1559Fees(client, level: level);
      final a = s.maxFeePerGas;
      final b = s.maxPriorityFeePerGas;
      if (a == null || b == null) return null;
      return (a, b);
    } catch (_) {
      return null;
    }
  }
}
