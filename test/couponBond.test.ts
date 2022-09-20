import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("CouponBond", function () {
  async function deployCouponBond() {
    const [owner, alice] = await ethers.getSigners();

    const CouponBond = await ethers.getContractFactory("CouponBond");
    const couponBond = await CouponBond.deploy();

    const Usdt = await ethers.getContractFactory("MockERC20");
    const usdt = await Usdt.deploy();

    return { couponBond, usdt, owner, alice };
  }

  describe("#addProduct", function () {
    it("should give", async function () {
      const startTs = 1662562800; // 2022-09-08 GMT+0900
      const endTs = 1694012400; // 2022-09-07 GMT+0900
      const { couponBond, usdt } = await loadFixture(deployCouponBond);
      /*
      await couponBond.addProduct(
        1000,
        usdt.address,
        ethers.utils.parseEther("100"), // bsc USDT or BUSD both use decimal 18, each token are worth $100.
        "ipfs://testuri",
        startTs,
        endTs
      );
      */
    });
  });

  describe("#claim", function () {
    this.beforeEach(async function () {
      // transfer monthly interest
      // set repaid
    });

    it("should allow users with zero balance to claim", async function () {
      const { couponBond } = await loadFixture(deployCouponBond);
    });

    it("should allow users to claim multiple times", async function () {
      const { couponBond } = await loadFixture(deployCouponBond);
    });

    context("when repaid", function () {
      it("should transfer principal + unclaimed interest at first", async function () {});
      it("should transfer 0 at second", async function () {});
    });
  });

  describe("#withdrawResidue", function () {
    it("should transfer _amount to the owner", async function () {});
  });
});
