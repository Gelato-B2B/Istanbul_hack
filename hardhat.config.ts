import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-waffle'
import {config as dotEnvConfig} from 'dotenv'

import 'hardhat-typechain'
import 'hardhat-jest-plugin'
import 'hardhat-tracer'
import axios from 'axios';

import {HardhatUserConfig} from 'hardhat/types'

dotEnvConfig()

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY || "";
const INCH_BEARER = process.env.INCH_BEARER || "";

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
    networks: {
        hardhat: {
            forking: {
                // eslint-disable-next-line
                enabled: true,
                url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY}`
            },
            chainId: 1
        },
        localhost: {}
    }
}

export default config
