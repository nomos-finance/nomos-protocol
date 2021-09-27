// @ts-ignore
import { HardhatNetworkForkingUserConfig, HardhatUserConfig } from 'hardhat/types';
import {
  eEthereumNetwork,
  ePolygonNetwork,
  eXDaiNetwork,
  eHecoNetwork,
  eHooNetwork,
  eArbitrumNetwork,
  eBscNetwork,
  eOkexNetwork,
  iParamsPerNetwork,
} from './helpers/types';

require('dotenv').config();

const INFURA_KEY = process.env.INFURA_KEY || '';
const ALCHEMY_KEY = process.env.ALCHEMY_KEY || '';
const TENDERLY_FORK_ID = process.env.TENDERLY_FORK_ID || '';
const FORK = process.env.FORK || '';
const FORK_BLOCK_NUMBER = process.env.FORK_BLOCK_NUMBER
  ? parseInt(process.env.FORK_BLOCK_NUMBER)
  : 0;

const GWEI = 1000 * 1000 * 1000;

export const buildForkConfig = (): HardhatNetworkForkingUserConfig | undefined => {
  let forkMode;
  if (FORK) {
    forkMode = {
      url: NETWORKS_RPC_URL[FORK],
    };
    if (FORK_BLOCK_NUMBER || BLOCK_TO_FORK[FORK]) {
      forkMode.blockNumber = FORK_BLOCK_NUMBER || BLOCK_TO_FORK[FORK];
    }
  }
  return forkMode;
};

export const NETWORKS_RPC_URL: iParamsPerNetwork<string> = {
  [eEthereumNetwork.kovan]: ALCHEMY_KEY
    ? `https://eth-kovan.alchemyapi.io/v2/${ALCHEMY_KEY}`
    : `https://kovan.infura.io/v3/${INFURA_KEY}`,
  [eEthereumNetwork.ropsten]: ALCHEMY_KEY
    ? `https://eth-ropsten.alchemyapi.io/v2/${ALCHEMY_KEY}`
    : `https://ropsten.infura.io/v3/${INFURA_KEY}`,
  [eEthereumNetwork.main]: ALCHEMY_KEY
    ? `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_KEY}`
    : `https://mainnet.infura.io/v3/${INFURA_KEY}`,
  [eEthereumNetwork.coverage]: 'http://localhost:8555',
  [eEthereumNetwork.hardhat]: 'http://localhost:8545',
  [eEthereumNetwork.buidlerevm]: 'http://localhost:8545',
  [eEthereumNetwork.tenderlyMain]: `https://rpc.tenderly.co/fork/${TENDERLY_FORK_ID}`,
  [eHecoNetwork.htestnet]: 'https://http-testnet.hecochain.com',
  [eHecoNetwork.heco]: 'https://http-mainnet.hecochain.com',
  [eHooNetwork.hoo]: 'https://http-mainnet.hoosmartchain.com',
  [eArbitrumNetwork.amain]: 'https://arbitrum.io/rpc',
  [eArbitrumNetwork.arinkeby]: 'https://rinkeby.arbitrum.io/rpc',
  [eBscNetwork.bsc]: 'https://bsc-dataseed1.binance.org',
  [eBscNetwork.bsctestnet]: 'https://data-seed-prebsc-1-s1.binance.org:8545',
  [eOkexNetwork.okex]: 'https://exchainrpc.okex.org',
  [ePolygonNetwork.mumbai]: 'https://rpc-mumbai.maticvigil.com',
  [ePolygonNetwork.matic]: 'https://rpc-mainnet.matic.network',
  [eXDaiNetwork.xdai]: 'https://rpc.xdaichain.com/',
};

export const NETWORKS_DEFAULT_GAS: iParamsPerNetwork<number> = {
  [eHecoNetwork.htestnet]: 65 * GWEI,
  [eHecoNetwork.heco]: 3 * GWEI,
  [eHooNetwork.hoo]: 1 * GWEI,
  [eArbitrumNetwork.amain]: 1 * GWEI,
  [eArbitrumNetwork.arinkeby]: 1 * GWEI,
  [eBscNetwork.bsc]: 1 * GWEI,
  [eBscNetwork.bsctestnet]: 1 * GWEI,
  [eOkexNetwork.okex]: 1 * GWEI,
  [eEthereumNetwork.kovan]: 1 * GWEI,
  [eEthereumNetwork.ropsten]: 65 * GWEI,
  [eEthereumNetwork.main]: 65 * GWEI,
  [eEthereumNetwork.coverage]: 65 * GWEI,
  [eEthereumNetwork.hardhat]: 65 * GWEI,
  [eEthereumNetwork.buidlerevm]: 65 * GWEI,
  [eEthereumNetwork.tenderlyMain]: 0.01 * GWEI,
  [ePolygonNetwork.mumbai]: 1 * GWEI,
  [ePolygonNetwork.matic]: 1 * GWEI,
  [eXDaiNetwork.xdai]: 1 * GWEI,
};

export const BLOCK_TO_FORK: iParamsPerNetwork<number | undefined> = {
  [eEthereumNetwork.main]: 12406069,
  [eEthereumNetwork.kovan]: undefined,
  [eEthereumNetwork.ropsten]: undefined,
  [eEthereumNetwork.coverage]: undefined,
  [eEthereumNetwork.hardhat]: undefined,
  [eEthereumNetwork.buidlerevm]: undefined,
  [eEthereumNetwork.tenderlyMain]: 12406069,
  [ePolygonNetwork.mumbai]: undefined,
  [ePolygonNetwork.matic]: undefined,
  [eXDaiNetwork.xdai]: undefined,
  [eHecoNetwork.htestnet]: undefined,
  [eHecoNetwork.heco]: undefined,
  [eHooNetwork.hoo]: undefined,
  [eArbitrumNetwork.amain]: undefined,
  [eArbitrumNetwork.arinkeby]: undefined,
  [eBscNetwork.bsc]: undefined,
  [eBscNetwork.bsctestnet]: undefined,
  [eOkexNetwork.okex]: undefined,
};
