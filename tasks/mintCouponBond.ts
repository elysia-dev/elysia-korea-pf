import { CouponBond } from "../typechain-types";
import { task } from "hardhat/config";
import readlineSync from "readline-sync";

const data = {
  amounts: [35, 268, 70, 88, 26, 18, 176, 14, 105, 35, 25, 70, 70],
  receivers: [
    "0x90c285e4081c9C430029B4eb17d62530E4787759",
    "0xc03fC335E38451E252DB1d81Dd3cCF0dD38be044",
    "0x5B5C11b7B2E21988282e07F785ab466f31bf4aaa",
    "0x8DA744b8eaa0E5e5A496aAc13C00d7Ab04150404",
    "0x6c88b2f5C60d83957BF0133e4197E6746fC5FBb2",
    "0x37dc32726fF3a5909bF1304bD5cD754Db7091Ec3",
    "0x5e8eD0d9Bdb8b8C091853F95B8527158D3dE8227",
    "0x0bE4582d728d02b3DE767037cD9610a1E7954400",
    "0x9623D74bEb813eaDb2818d7C0D4F3c0eDb8751e9",
    "0xc34c44f0de6E6D4c87620376C600fe654209CF41",
    "0x7E635C76AAAFd73f700968a452d753b4f8a56424",
    "0xF6e43631d7ee6Dbf1dD08C3761A51c0037Fb9390",
    "0xFDf8BbE9f02F3392dD0cA8A48eE502cEF2Cf899a",
  ],
};

const addProduct = task("mintCouponBond", "Mint CouponBond product").setAction(
  async function (taskArgs, hre) {
    const deployment = await hre.deployments.get("CouponBond");
    const { deployer } = await hre.getNamedAccounts();
    console.log("deployer: ", deployer);

    const couponBond = (await hre.ethers.getContractAt(
      deployment.abi,
      deployment.address
    )) as CouponBond;

    const id = 0;

    // 2. Mint NFTs to test accounts
    if (hre.network.name === "bsc") {
      console.log("Deploy to bsc");
      const answer: string = readlineSync.question("Proceed? [y/n]\n");
      if (answer.toLowerCase() === "y") {
        const tx = await couponBond.mintBatch(id, data.receivers, data.amounts);
      }
    } else {
      console.log("testnet");
    }
  }
);

export default addProduct;
