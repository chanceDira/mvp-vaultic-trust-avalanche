import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Deploys MockERC20 used as payment token for Vaultic Trust (testnets / local).
 * Use PAYMENT_TOKEN_ADDRESS env on mainnet to skip and use existing stablecoin.
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployMockPaymentToken: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("MockERC20", {
    from: deployer,
    args: ["Mock USDC", "USDC", 6],
    log: true,
    autoMine: true,
  });
};

export default deployMockPaymentToken;
deployMockPaymentToken.tags = ["MockPaymentToken"];
