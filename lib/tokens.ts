import {NETWORKS} from './networks'

export const SYMBOLS = {
  USDC: "USDC",
};

export const ADDRESSES = {
  GNOSIS: new Map([
    [SYMBOLS.USDC, "0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83"],
  ]),
  GNOSIS_CHIADO_TESTNET: new Map([
    [SYMBOLS.USDC, "0xDDAfbb505ad214D7b80b1f830fcCc89B60fb7A83"],
  ]),
  MANTLE: new Map([
    [SYMBOLS.USDC, "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9"],
  ]),
  MANTLE_TESTNET: new Map([
    // TODO: not really sure if this is the right address
    [SYMBOLS.USDC, "0x9c873d9A44013D1aa2605f2bE61F6209980174f6"],
  ]),
  POLYGON_ZKEVM_TESTNET: new Map([
    [SYMBOLS.USDC, "0x557278364B136a8D7686016b1930c8C7136d8af9"],
  ]),
}

export const getTokenAddressesByNetwork = (network: string) => {
  switch (network) {
    case NETWORKS.GNOSIS:
      return ADDRESSES.GNOSIS;
    case NETWORKS.GNOSIS_CHIADO:
      return ADDRESSES.GNOSIS_CHIADO_TESTNET;
    case NETWORKS.MANTLE_TESTNET:
      return ADDRESSES.MANTLE_TESTNET;
    case NETWORKS.POLYGON_ZKEVM_TESTNET:
      return ADDRESSES.POLYGON_ZKEVM_TESTNET;
    case NETWORKS.MANTLE:
      return ADDRESSES.MANTLE;
    default:
      throw new Error(`Unknown network: ${network}`);
  }
}
