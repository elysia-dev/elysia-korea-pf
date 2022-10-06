import { ethers } from "ethers";
import { task } from "hardhat/config";

const addProduct = task(
  "addBulletProduct",
  "Add a BulletBond product"
).setAction(async function (taskArgs, hre) {
  const deployment = await hre.deployments.get("BulletBond");
  const usdt = await hre.deployments.get("Usdt");

  const bulletBond = await hre.ethers.getContractAt(
    deployment.abi,
    deployment.address
  );

  const arg = {
    initialSupply: 1000,
    token: usdt.address,
    value: ethers.utils.parseEther("100"),
    uri: "ipfs://QmZ4moQm38hSoLW7mMjQtXmvX2CVv1jjmAM39Us7Zug69T",
    startTs: 1662562800,
    endTs: 1694012400,
  };

  const tx = await bulletBond.addProduct(
    arg.initialSupply,
    arg.token,
    arg.value,
    arg.uri,
    arg.startTs,
    arg.endTs
  );

  await tx.wait();
});

export default addProduct;
