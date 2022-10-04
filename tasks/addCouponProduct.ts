import { CouponBond } from "../typechain-types";
import { ethers, Event } from "ethers";
import { task } from "hardhat/config";

const addProduct = task("addCouponProduct", "Add a CouponBond product")
  .addFlag("live", "Indicate whether to add product on live")
  .setAction(async function (taskArgs, hre) {
    const deployment = await hre.deployments.get("CouponBond");
    const usdt = await hre.deployments.get("Usdt");
    const { deployer } = await hre.getNamedAccounts();
    console.log("deployer: ", deployer);

    const couponBond = (await hre.ethers.getContractAt(
      deployment.abi,
      deployment.address
    )) as CouponBond;

    const value = ethers.utils.parseEther("100");
    const startTs = 1662562800;
    const endTs = 1694012400;
    const SECONDS_PER_YEAR = 365 * 86400;

    const arg = {
      token: usdt.address,
      value,
      interesPerSecond: value.mul(30).div(100 * (endTs - startTs)), // 30%
      overdueInterestPerSecond: value.mul(3).div(100 * SECONDS_PER_YEAR), // 3%
      uri: "ipfs://Qmdkh5Ur1ECdGMDXX9QKHJpiToZxUkCEe9MPMHhDyUNtbE",
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
    const events = receipt.events?.filter((x: Event) => {
      x.event === "ProductAdded";
    });
    console.log(events);

    // 2. Mint NFTs to test accounts
    if (taskArgs.live) {
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
