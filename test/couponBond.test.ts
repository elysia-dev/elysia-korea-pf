import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

// TODO:
describe("CouponBond", function () {
  async function deployCouponBond() {
    const CouponBond = await ethers.getContractFactory("CouponBond");
    const couponBond = await CouponBond.deploy();

    return { couponBond };
  }

  describe("#addProduct", function () {
    it("should give", async function () {
      const { couponBond } = await loadFixture(deployCouponBond);
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
