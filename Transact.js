const dotenv = require('dotenv');
dotenv.config();
const { providers, Wallet, Contract, utils } = require('ethers');

const GNOSIS_CHAIN_RPC = "https://rpc.gnosischain.com/"
const GNOSIS_CHAIN_CONTRACT = require('./deployments/gnosis/IntentBoost.json');

const MANTLE_RPC = "https://rpc.mantle.xyz/"
const MANTLE_CONTRACT = require('./deployments/mantle/IntentBoost.json');

const POLYGON_ZKEVM_TESTNET_RPC = "https://rpc.public.zkevm-test.net";
const POLYGON_ZKEVM_CONTRACT = require('./deployments/polygonZkEvmTestnet/IntentBoost.json');

async function main() {
  const provider = new providers.JsonRpcProvider(
    // GNOSIS_CHAIN_RPC
    // MANTLE_RPC
    POLYGON_ZKEVM_TESTNET_RPC
  )

  // const deploymentInfo = GNOSIS_CHAIN_CONTRACT;
  // const deploymentInfo = MANTLE_CONTRACT;
  const deploymentInfo = POLYGON_ZKEVM_CONTRACT;

  const wallet = new Wallet(process.env.PRIVATE_KEY, provider);

  const intentBoostContract = new Contract(
    deploymentInfo.address,
    deploymentInfo.abi,
    wallet,
  );

  const usdcAddress = await intentBoostContract.lockUSDC();
  console.log({ usdcAddress });

  /** Manage paused state (onlyOwner) */
  // console.log({ paused: await intentBoostContract.paused() });
  // await intentBoostContract.setPaused(true).then(tx => tx.wait());
  // console.log({ paused: await intentBoostContract.paused() });
  // await intentBoostContract.setPaused(false).then(tx => tx.wait());
  // console.log({ paused: await intentBoostContract.paused() });

  const gasPrice = await provider.getGasPrice();
  console.log({ gasPrice: utils.formatUnits(gasPrice, 'gwei') });

  /** Create pool */
  // await intentBoostContract.createLendingPool(
  //   10, // interest rate
  //   utils.parseEther('0.001'), // capital
  //   24, // loan duration
  //   80, // liquidation threshold
  //   60, // collateral ratio
  //   [], {
  //     value: utils.parseEther('0.001'),
  //     gasLimit: 1000000
  //   }
  // ).then(tx => tx.wait());
}

main()
  .catch(console.error);
