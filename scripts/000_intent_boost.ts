import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {getTokenAddressesByNetwork, SYMBOLS} from '../lib/tokens'

const deployFunction: DeployFunction = async function (
  hre: HardhatRuntimeEnvironment,
) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const tokenAddresses = getTokenAddressesByNetwork(hre.network.name);
  const usdcAddress = tokenAddresses.get(SYMBOLS.USDC);
  if (!usdcAddress) {
    throw new Error("USDC address not found");
  }

  console.log({ usdcAddress });

  const name = "IntentBoost";
  await deploy(name, {
    contract: "contracts/IntentBoost.sol:intentBoost",
    from: deployer,
    log: true,
    args: [usdcAddress],
  });
};

deployFunction.tags = [];

export default deployFunction;
