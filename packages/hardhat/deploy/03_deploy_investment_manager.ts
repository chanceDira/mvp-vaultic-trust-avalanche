import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

const PROTOCOL_FEE_BPS = 50; // 0.5%

/**
 * Deploys VaulticInvestmentManager (UUPS proxy) and sets registry tokenizer to it.
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployInvestmentManager: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy, get } = hre.deployments;

  const registry = await get("VaulticAssetRegistry");
  const paymentToken = await get("MockERC20");
  const tokenImpl = await get("VaulticFractionalOwnershipToken");

  await deploy("VaulticInvestmentManager", {
    from: deployer,
    proxy: {
      proxyContract: "UUPS",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            registry.address,
            paymentToken.address,
            tokenImpl.address,
            deployer, // feeTreasury
            PROTOCOL_FEE_BPS,
            deployer, // owner
          ],
        },
      },
    },
    log: true,
    autoMine: true,
  });

  const registryContract = await hre.ethers.getContract<Contract>("VaulticAssetRegistry", deployer);
  // Cap gas so local/CI nodes with low block gas limit (e.g. 16_777_216) accept the tx
  const setTokenizerGasLimit = 500_000;
  await registryContract.setTokenizer((await get("VaulticInvestmentManager")).address, {
    gasLimit: setTokenizerGasLimit,
  });
  console.log("VaulticAssetRegistry tokenizer set to VaulticInvestmentManager");
};

export default deployInvestmentManager;
deployInvestmentManager.tags = ["VaulticInvestmentManager"];
deployInvestmentManager.dependencies = [
  "VaulticAssetRegistry",
  "VaulticFractionalOwnershipTokenImpl",
  "MockPaymentToken",
];
