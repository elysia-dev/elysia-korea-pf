import { ethers } from "ethers";
import { BulletBond } from "../typechain-types";
import { task } from "hardhat/config";

const addProduct = task("addProduct", "Add a product").setAction(
  async function (taskArgs, hre) {
    const { deployer } = await hre.getNamedAccounts();
    const deployment = await hre.deployments.get("BulletBond");
    const usdt = await hre.deployments.get("Usdt");

    const bulletBond = (await hre.ethers.getContractAt(
      deployment.abi,
      deployment.address
    )) as BulletBond;

    const arg = {
      initialSupply: 1000,
      token: usdt.address,
      value: ethers.utils.parseEther("100"),
      uri: "ipfs://TODO",
      startTs: 1662562800,
      endTs: 1694012400,
    };

    await bulletBond
      .connect(deployer)
      .addProduct(
        arg.initialSupply,
        arg.token,
        arg.value,
        arg.uri,
        arg.startTs,
        arg.endTs
      );
  }
);

export default addProduct;
