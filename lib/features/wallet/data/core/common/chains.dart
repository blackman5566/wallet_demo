enum ChainKind { evm }

class Chain {
  final int id;              // EVM: chainId；Solana: 用 501 代表 Devnet
  final String name;
  final String rpc;
  final String symbol;
  final ChainKind kind;
  final String explorer;
  final String displaySymbol;
  const Chain({
    required this.id,
    required this.name,
    required this.rpc,
    required this.symbol,
    required this.kind,
    required this.explorer,
    required this.displaySymbol,
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
    displaySymbol:'ETH',
  ),
  Chain(
    id: 80002, // Amoy Testnet Chain ID
    name: 'Polygon Amoy',
    rpc: 'https://rpc-amoy.polygon.technology',
    symbol: 'MATIC',
    kind: ChainKind.evm,
    explorer: 'https://amoy.polygonscan.com',
    displaySymbol:'POL',
  ),
];
