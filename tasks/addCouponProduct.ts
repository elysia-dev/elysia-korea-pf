import { CouponBond } from "../typechain-types";
import { ethers, Event } from "ethers";
import { task } from "hardhat/config";

const getTimestamp = () => Math.floor(new Date().getTime() / 1000);

const addProduct = task(
  "addCouponProduct",
  "Add a CouponBond product"
).setAction(async function (taskArgs, hre) {
  const deployment = await hre.deployments.get("CouponBond");
  const usdt = await hre.deployments.get("Usdt");
  const { deployer } = await hre.getNamedAccounts();
  console.log("deployer: ", deployer);

  const couponBond = (await hre.ethers.getContractAt(
    deployment.abi,
    deployment.address
  )) as CouponBond;

  const value = ethers.utils.parseEther("100");
  const startTs = 1662562800; // 2022.09.08 00:00:00 GMT+09:00
  const endTs = 1694012400; // 2023.09.07 00:00:00 GMT+09:00
  const SECONDS_PER_YEAR = 365 * 86400;

  const arg = {
    token: usdt.address,
    value,
    interesPerSecond: value.mul(30).div(100 * (endTs - startTs)), // 30%, endTs - startTs = 364 days
    overdueInterestPerSecond: value.mul(3).div(100 * SECONDS_PER_YEAR), // 3%
    uri: "ipfs://QmZSm5B5f8yJ5keUXkGnENuaVqtoWPR7g7SkjWo771yv9x",
    startTs,
    endTs,
  } as const;

  // 1. Add product
  const tx = await couponBond.addProduct(
    arg.token,
    arg.value,
    arg.interesPerSecond,
    arg.overdueInterestPerSecond,
    arg.uri,
    arg.startTs,
    arg.endTs
  );

  const receipt = await tx.wait();

  // 2. Mint NFTs to test accounts
  if (hre.network.name === "bsc") {
    console.log("Deploy to live env");
    // TODO: mint with the real account list
  } else {
    console.log("Deploy to test env");
    const [test1, test2] = await hre.getUnnamedAccounts();
    console.log(test1, test2);
    const id = 0;
    const initialSupply = 1000;
    await couponBond.mintBatch(
      id,
      [deployer, test1, test2],
      [initialSupply - 100, 37, 63]
    );
  }
});

export default addProduct;
