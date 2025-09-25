enum ChainKind { evm }

class Chain {
  final int id;              // EVM: chainId；Solana: 用 501 代表 Devnet
  final String name;
  final String rpc;
  final String symbol;
  final ChainKind kind;
  final String explorer;
  const Chain({
    required this.id,
    required this.name,
    required this.rpc,
    required this.symbol,
    required this.kind,
    required this.explorer,
  });
}

const supportedChains = <Chain>[
  Chain(
    id: 11155111,
    name: 'Ethereum Sepolia',
    rpc: 'https://ethereum-sepolia-rpc.publicnode.com',
    symbol: 'ETH',
    kind: ChainKind.evm,
    explorer: 'https://sepolia.etherscan.io',
  ),
];
