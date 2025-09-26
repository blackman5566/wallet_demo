import 'package:web3dart/web3dart.dart';

String formatEth(BigInt wei, {int fraction = 4}) {
  final v = EtherAmount.fromBigInt(EtherUnit.wei, wei)
      .getValueInUnit(EtherUnit.ether);
  if (v > 0 && v < 0.0001) return '<0.0001';
  final s = v.toStringAsFixed(fraction);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

String formatSol(BigInt lamports, {int fraction = 4}) {
  // 1 SOL = 1e9 lamports
  final v = lamports.toDouble() / 1e9;
  if (v > 0 && v < 0.0001) return '<0.0001';
  final s = v.toStringAsFixed(fraction);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}