import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

// TODO:
describe("CouponBond", function () {
  async function deployCouponBond() {
    const CouponBond = await ethers.getContractFactory("CouponBond");
    const couponBond = await CouponBond.deploy();

    return { couponBond };
  }

  describe("#mint", function () {
    it("should give", async function () {
      const { couponBond } = await loadFixture(deployCouponBond);
      console.log(await couponBond.products(0));
    });
  });

  describe("#claim", function () {
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
});
