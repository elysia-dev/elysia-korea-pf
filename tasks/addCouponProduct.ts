import { ethers } from "ethers";
import { task } from "hardhat/config";

const addProduct = task(
  "addCouponProduct",
  "Add a CouponBond product"
).setAction(async function (taskArgs, hre) {
  const deployment = await hre.deployments.get("CouponBond");
  const usdt = await hre.deployments.get("Usdt");

  const bulletBond = await hre.ethers.getContractAt(
    deployment.abi,
    deployment.address
  );

  const value = ethers.utils.parseEther("100");
  const startTs = 1662562800;
  const endTs = 1694012400;
  const SECONDS_PER_YEAR = 365 * 86400;

  const arg = {
    initialSupply: 1000,
    token: usdt.address,
    value,
    interesPerSecond: value.mul(30).div(100 * (endTs - startTs)), // 30%
    overdueInterestPerSecond: value.mul(3).div(100 * SECONDS_PER_YEAR), // 3%
    uri: "ipfs://Qmdkh5Ur1ECdGMDXX9QKHJpiToZxUkCEe9MPMHhDyUNtbE",
    startTs,
    endTs,
  } as const;

  const tx = await bulletBond.addProduct(
    arg.initialSupply,
    arg.token,
    arg.value,
    arg.interesPerSecond,
    arg.overdueInterestPerSecond,
    arg.uri,
    arg.startTs,
    arg.endTs
  );

  await tx.wait();
});

export default addProduct;
