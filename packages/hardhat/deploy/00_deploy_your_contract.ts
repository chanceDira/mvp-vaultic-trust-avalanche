import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Deploys MockERC20 used as payment token for Vaultic Trust (local / testnets only).
 * For production: set PAYMENT_TOKEN_ADDRESS to a real stablecoin (e.g. USDC on Avalanche)
 * and deploy; the Investment Manager will use that address instead of deploying MockERC20.
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployMockPaymentToken: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (process.env.PAYMENT_TOKEN_ADDRESS) {
    console.log("PAYMENT_TOKEN_ADDRESS set; skipping MockERC20 deploy (using existing token)");
    return;
  }
  if (hre.network.name === "avalancheFuji") {
    console.log("avalancheFuji: skipping MockERC20 (using Fuji USDC as payment token)");
    return;
  }
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
