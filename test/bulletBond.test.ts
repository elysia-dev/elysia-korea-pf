import { MockERC20 } from "./../typechain-types/contracts/mocks/MockERC20";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";
import { expect } from "chai";
import { BulletBond } from "../typechain-types";

describe("BulletBond", function () {
  async function deployBulletBond() {
    const [owner, alice] = await ethers.getSigners();

    const BulletBond = await ethers.getContractFactory("BulletBond");
    const bulletBond = await BulletBond.deploy();

    const Usdt = await ethers.getContractFactory("MockERC20");
    const usdt = await Usdt.deploy();

    return { bulletBond, usdt, owner, alice };
  }

  async function addProduct(bulletBond: BulletBond, usdt: MockERC20) {
    const startTs = 0;
    const endTs = 0;

    return bulletBond.addProduct(
      1000,
      usdt.address,
      ethers.utils.parseEther("100"),
      "ipfs://testuri",
      startTs,
      endTs
    );
  }

  describe("#addProduct", function () {
    it("should be only allowed to the owner", async function () {
      const { bulletBond, usdt, alice } = await loadFixture(deployBulletBond);

      const startTs = 0;
      const endTs = 0;

      await expect(
        bulletBond
          .connect(alice)
          .addProduct(
            1000,
            usdt.address,
            ethers.utils.parseEther("100"),
            "ipfs://testuri",
            startTs,
            endTs
          )
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should mint _initialSupply", async function () {
      const { bulletBond, usdt } = await loadFixture(deployBulletBond);

      await addProduct(bulletBond, usdt);
      expect(await bulletBond.totalSupply(0)).to.eq(1000);
    });

    it("should set given info", async function () {
      const { bulletBond, usdt } = await loadFixture(deployBulletBond);

      await addProduct(bulletBond, usdt);
      const product = await bulletBond.products(0);
      expect(product.token).to.eq(usdt.address);
    });
  });

  describe("#setURI", function () {
    it("should only allowd to the owner", async function () {
      const { bulletBond } = await loadFixture(deployBulletBond);
      const id = 0;
      const uri = "ipfs://test";
      await bulletBond.setURI(id, uri);
      expect((await bulletBond.products(0)).uri).to.equal(uri);
    });
  });

  describe("#repay", function () {
    it("should add the finalValue of the product by _finalValue", async function () {
      const { bulletBond, usdt } = await loadFixture(deployBulletBond);
      await addProduct(bulletBond, usdt);

      const finalValue = ethers.utils.parseEther("115");
      const totalFinalValue = finalValue.mul(1000);

      await usdt.approve(bulletBond.address, totalFinalValue);
      await bulletBond.repay(0, finalValue, totalFinalValue);
      const product = await bulletBond.products(0);

      expect(product.finalValue).to.eq(finalValue);
    });

    it("should transfer finalValue * totalSupply(id)", async function () {
      const { bulletBond, usdt } = await loadFixture(deployBulletBond);
      await addProduct(bulletBond, usdt);

      const finalValue = ethers.utils.parseEther("115");
      const totalFinalValue = finalValue.mul(1000);
      await usdt.approve(bulletBond.address, totalFinalValue);

      await expect(
        bulletBond.repay(0, finalValue, totalFinalValue)
      ).to.changeTokenBalance(usdt, bulletBond, totalFinalValue);
    });
  });

  describe("#claim", function () {
    it("should revert when the project is not repaid", async function () {
      const { bulletBond, usdt, alice } = await loadFixture(deployBulletBond);
      const id = 0;
      await expect(
        bulletBond.claim(alice.address, id)
      ).to.revertedWithCustomError(bulletBond, "NotRepaid");
    });

    it("should revert when a user with zero balance claims", async function () {
      // Setup
      const { bulletBond, usdt, alice } = await loadFixture(deployBulletBond);
      await addProduct(bulletBond, usdt);
      const id = 0;

      const finalValue = ethers.utils.parseEther("115");
      const totalFinalValue = finalValue.mul(1000);

      await usdt.approve(bulletBond.address, totalFinalValue);
      await bulletBond.repay(id, finalValue, totalFinalValue);

      // Check
      await expect(
        bulletBond.claim(alice.address, id)
      ).to.revertedWithCustomError(bulletBond, "ZeroBalanceClaim");
    });

    context("when repaid", function () {
      let testEnv: any = {};

      beforeEach(async function () {
        const { bulletBond, usdt, owner, alice } = await loadFixture(
          deployBulletBond
        );
        await addProduct(bulletBond, usdt);
        const id = 0;
        const amount = 33;

        const finalValue = ethers.utils.parseEther("115");
        const totalFinalValue = finalValue.mul(1000);

        await usdt.approve(bulletBond.address, totalFinalValue);
        await bulletBond.repay(id, finalValue, totalFinalValue);

        await bulletBond.safeTransferFrom(
          owner.address,
          alice.address,
          id,
          amount,
          []
        );

        testEnv.bulletBond = bulletBond;
        testEnv.usdt = usdt;
        testEnv.owner = owner;
        testEnv.alice = alice;
      });

      it("should burn _to's all nfts", async function () {
        const { bulletBond, alice } = testEnv;
        const id = 0;

        await expect(bulletBond.claim(alice.address, id));

        expect(await bulletBond.balanceOf(alice.address, id)).to.eq(0);
      });

      it("should transfer principal + unclaimed interest at first", async function () {
        const { bulletBond, usdt, alice } = testEnv;
        const id = 0;

        await expect(bulletBond.claim(alice.address, id)).to.changeTokenBalance(
          usdt,
          alice.address,
          ethers.utils.parseEther("115").mul(33)
        );
      });

      it("should revert at second", async function () {
        const { bulletBond, usdt, alice } = testEnv;
        const id = 0;

        await bulletBond.claim(alice.address, id);
        await expect(
          bulletBond.claim(alice.address, id)
        ).to.revertedWithCustomError(bulletBond, "ZeroBalanceClaim");
      });
    });
  });

  describe("#withdrawResidue", function () {
    let testEnv: any = {};

    beforeEach(async function () {
      const { bulletBond, usdt, owner, alice } = await loadFixture(
        deployBulletBond
      );
      await addProduct(bulletBond, usdt);
      const id = 0;
      const amount = 33;

      const finalValue = ethers.utils.parseEther("115");
      const totalFinalValue = finalValue.mul(1000);

      await usdt.approve(bulletBond.address, totalFinalValue);
      await bulletBond.repay(id, finalValue, totalFinalValue);

      await bulletBond.safeTransferFrom(
        owner.address,
        alice.address,
        id,
        amount,
        []
      );

      await bulletBond.claim(alice.address, id);

      testEnv.bulletBond = bulletBond;
      testEnv.usdt = usdt;
      testEnv.owner = owner;
      testEnv.alice = alice;
    });

    it("should withdraw remaining stablecoins", async function () {
      const { bulletBond, alice } = testEnv;
      const id = 0;
      await expect(
        bulletBond.connect(alice).withdrawResidue(id)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should withdraw remaining stablecoins", async function () {
      const { bulletBond, usdt, owner } = testEnv;
      const id = 0;
      const product = await bulletBond.products(id);
      const remainingAmount = 967; // 1000 - 33

      await expect(bulletBond.withdrawResidue(id)).to.changeTokenBalance(
        usdt,
        owner,
        product.finalValue.mul(remainingAmount)
      );
    });

    it("should not burn unclaimed nfts", async function () {
      const { bulletBond, owner } = testEnv;
      const id = 0;
      const remainingAmount = 967; // 1000 - 33
      await bulletBond.withdrawResidue(id);
      expect(await bulletBond.balanceOf(owner.address, id)).to.eq(
        remainingAmount
      );
    });
  });
});
