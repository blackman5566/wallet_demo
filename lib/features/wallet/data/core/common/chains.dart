enum ChainKind { evm,sol }

class Chain {
  final int id;
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
  Chain(
    id: 102, // Devnet/測試網
    name: 'Solana Devnet',
    rpc: 'https://api.devnet.solana.com',
    symbol: 'SOL',
    kind: ChainKind.sol,
    explorer: 'https://explorer.solana.com/?cluster=devnet',
    displaySymbol: 'SOL',
  )
];

// const supportedChains = <Chain>[
//   // -------------------------------
//   // Ethereum
//   // -------------------------------
//   Chain(
//     id: 1,
//     name: 'Ethereum Mainnet',
//     rpc: 'https://eth-mainnet.g.alchemy.com/v2/<YOUR_KEY>',
//     symbol: 'ETH',
//     kind: ChainKind.evm,
//     explorer: 'https://etherscan.io',
//     displaySymbol: 'ETH',
//   ),
//   Chain(
//     id: 11155111,
//     name: 'Ethereum Sepolia',
//     rpc: 'https://ethereum-sepolia-rpc.publicnode.com',
//     symbol: 'ETH',
//     kind: ChainKind.evm,
//     explorer: 'https://sepolia.etherscan.io',
//     displaySymbol: 'ETH',
//   ),
//
//   // -------------------------------
//   // Polygon
//   // -------------------------------
//   Chain(
//     id: 137,
//     name: 'Polygon Mainnet',
//     rpc: 'https://polygon-rpc.com',
//     symbol: 'MATIC',
//     kind: ChainKind.evm,
//     explorer: 'https://polygonscan.com',
//     displaySymbol: 'POL', // UI 想顯示 POL 可自訂
//   ),
//   Chain(
//     id: 80002,
//     name: 'Polygon Amoy',
//     rpc: 'https://rpc-amoy.polygon.technology',
//     symbol: 'MATIC',
//     kind: ChainKind.evm,
//     explorer: 'https://amoy.polygonscan.com',
//     displaySymbol: 'POL',
//   ),
//
//   // -------------------------------
//   // BNB Smart Chain
//   // -------------------------------
//   Chain(
//     id: 56,
//     name: 'BNB Smart Chain',
//     rpc: 'https://bsc-dataseed.binance.org',
//     symbol: 'BNB',
//     kind: ChainKind.evm,
//     explorer: 'https://bscscan.com',
//     displaySymbol: 'BNB',
//   ),
//   Chain(
//     id: 97,
//     name: 'BNB Testnet',
//     rpc: 'https://data-seed-prebsc-1-s1.binance.org:8545/',
//     symbol: 'BNB',
//     kind: ChainKind.evm,
//     explorer: 'https://testnet.bscscan.com',
//     displaySymbol: 'BNB',
//   ),
//
//   // -------------------------------
//   // Arbitrum
//   // -------------------------------
//   Chain(
//     id: 42161,
//     name: 'Arbitrum One',
//     rpc: 'https://arb1.arbitrum.io/rpc',
//     symbol: 'ETH',
//     kind: ChainKind.evm,
//     explorer: 'https://arbiscan.io',
//     displaySymbol: 'ETH',
//   ),
//   Chain(
//     id: 421614,
//     name: 'Arbitrum Sepolia',
//     rpc: 'https://sepolia-rollup.arbitrum.io/rpc',
//     symbol: 'ETH',
//     kind: ChainKind.evm,
//     explorer: 'https://sepolia.arbiscan.io',
//     displaySymbol: 'ETH',
//   ),
//
//   // -------------------------------
//   // Optimism
//   // -------------------------------
//   Chain(
//     id: 10,
//     name: 'Optimism',
//     rpc: 'https://mainnet.optimism.io',
//     symbol: 'ETH',
//     kind: ChainKind.evm,
//     explorer: 'https://optimistic.etherscan.io',
//     displaySymbol: 'ETH',
//   ),
//   Chain(
//     id: 11155420,
//     name: 'Optimism Sepolia',
//     rpc: 'https://sepolia.optimism.io',
//     symbol: 'ETH',
//     kind: ChainKind.evm,
//     explorer: 'https://sepolia-optimistic.etherscan.io',
//     displaySymbol: 'ETH',
//   ),
//
//   // -------------------------------
//   // Avalanche
//   // -------------------------------
//   Chain(
//     id: 43114,
//     name: 'Avalanche C-Chain',
//     rpc: 'https://api.avax.network/ext/bc/C/rpc',
//     symbol: 'AVAX',
//     kind: ChainKind.evm,
//     explorer: 'https://snowtrace.io',
//     displaySymbol: 'AVAX',
//   ),
//   Chain(
//     id: 43113,
//     name: 'Avalanche Fuji',
//     rpc: 'https://api.avax-test.network/ext/bc/C/rpc',
//     symbol: 'AVAX',
//     kind: ChainKind.evm,
//     explorer: 'https://testnet.snowtrace.io',
//     displaySymbol: 'AVAX',
//   ),
//
//   // -------------------------------
//   // Base
//   // -------------------------------
//   Chain(
//     id: 8453,
//     name: 'Base Mainnet',
//     rpc: 'https://mainnet.base.org',
//     symbol: 'ETH',
//     kind: ChainKind.evm,
//     explorer: 'https://basescan.org',
//     displaySymbol: 'ETH',
//   ),
//   Chain(
//     id: 84532,
//     name: 'Base Sepolia',
//     rpc: 'https://sepolia.base.org',
//     symbol: 'ETH',
//     kind: ChainKind.evm,
//     explorer: 'https://sepolia.basescan.org',
//     displaySymbol: 'ETH',
//   ),
// ];
