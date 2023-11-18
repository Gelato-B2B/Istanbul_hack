import {NETWORKS} from './networks'

export const SYMBOLS = {
  USDC: "USDC",
};

export const ADDRESSES = {
  GNOSIS_CHIADO_TESTNET: new Map([
      [SYMBOLS.USDC, "0xe2c6b1E40907973637C1fCe6caf848DC275596d4"],
  ]),
  MANTLE_TESTNET: new Map([
    // TODO: not really sure if this is the right address
    [SYMBOLS.USDC, "0x9c873d9A44013D1aa2605f2bE61F6209980174f6"],
  ])
}

export const getTokenAddressesByNetwork = (network: string) => {
  switch (network) {
    case NETWORKS.GNOSIS_CHIADO:
      return ADDRESSES.GNOSIS_CHIADO_TESTNET;
    case NETWORKS.MANTLE_TESTNET:
      return ADDRESSES.MANTLE_TESTNET;
    default:
      throw new Error(`Unknown network: ${network}`);
  }
}
