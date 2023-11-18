import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-waffle'
import "hardhat-deploy";
import {config as dotEnvConfig} from 'dotenv'

import 'hardhat-typechain'
import 'hardhat-jest-plugin'
import 'hardhat-tracer'
import axios from 'axios';

import {HardhatUserConfig} from 'hardhat/types'

dotEnvConfig()

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY || "";
const INCH_BEARER = process.env.INCH_BEARER || "";
const PK = process.env.PRIVATE_KEY || "";

axios.defaults.headers.common = {
    'Authorization': `Bearer ${INCH_BEARER}`
};

const config: HardhatUserConfig = {
    defaultNetwork: 'hardhat',
    solidity: {
        compilers: [
            {
                version: "0.8.17",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            },
        ]
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
    },
    paths: {
        deploy: "scripts",
    },
    networks: {
        hardhat: {
            forking: {
                // eslint-disable-next-line
                enabled: true,
                url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY}`
            },
            chainId: 1
        },
        localhost: {},
        mantle: {
            url: "https://rpc.mantle.xyz",
            accounts: [PK],
        },
        mantleTestnet: {
            url: "https://rpc.testnet.mantle.xyz",
            accounts: [PK]
        },
        chiado: {
            url: "https://rpc.chiadochain.net",
            // gasPrice: 1000000000,
            accounts: [PK],
        },
        gnosis: {
            url: "https://rpc.gnosischain.com/",
            accounts: [PK],
        },
        polygonZkEvmTestnet: {
            url: `https://rpc.public.zkevm-test.net`,
            accounts: [PK],
        },
    },
}

export default config;
