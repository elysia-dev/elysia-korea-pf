pragma solidity 0.8.9;

import "forge-std/Test.sol";
import "../../contracts/CouponBond.sol";
import "../../contracts/test/MockERC20.sol";

contract CouponBondTest is Test {
    CouponBond couponBond;
    MockERC20 usdt;

    uint64 startTs = 1662562800; // 2022-09-08 GMT+0900
    uint64 endTs = 1694012400; // 2022-09-07 GMT+0900
    uint256 constant id = 0;
    uint256 principalPerToken = 100 * 1e18;
    uint256 interestPerTokenInSecond =
        (principalPerToken * 3) / (10 * (endTs - startTs));
    uint256 totalSupply = 1000;

    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);
    address usdtOwner = address(0x4);

    uint256 aliceBalance = 1;
    uint256 bobBalance = 100;

    function setUp() public {
        vm.prank(usdtOwner);
        usdt = new MockERC20();

        vm.startPrank(owner);
        couponBond = new CouponBond();
        couponBond.addProduct(
            totalSupply,
            address(usdt),
            principalPerToken, // bsc USDT or BUSD both use decimal 18, each token are worth $100.
            interestPerTokenInSecond,
            "ipfs://testuri",
            startTs,
            endTs
        );
        vm.stopPrank();

        vm.prank(usdtOwner);
        usdt.transfer(address(couponBond), 130 * 1000 * 1e18); // 30% interest i.e. $100 -> $130

        vm.startPrank(owner);
        couponBond.safeTransferFrom(owner, alice, id, aliceBalance, "");
        couponBond.safeTransferFrom(owner, bob, id, bobBalance, "");
    }

    // 100 seconds elapsed -> claim
    function testClaimBeforeRepay(uint64 elapsed) public {
        vm.assume(elapsed <= endTs - startTs);
        vm.warp(startTs + elapsed);

        couponBond.claim(alice, id);

        assertEq(usdt.balanceOf(alice), interestPerTokenInSecond * elapsed); // interest transferred
        assertEq(couponBond.balanceOf(alice, id), aliceBalance); // Not burned

        couponBond.claim(alice, id);
        assertEq(usdt.balanceOf(alice), interestPerTokenInSecond * elapsed); // No duplicate interest
    }

    // pass after endTs -> claim -> setRepaid -> claim
    function testClaimBeforeAndAfterRepay(uint64 elapsed) public {
        vm.assume(elapsed <= type(uint64).max - endTs); // no invalid timestamp
        vm.warp(endTs + elapsed);

        // 1. claim before repay
        couponBond.claim(alice, id);

        assertEq(
            usdt.balanceOf(alice),
            interestPerTokenInSecond * (endTs - startTs)
        );

        // 2. claim after repay
        couponBond.setRepaid(id);
        couponBond.claim(alice, id);

        assertEq(
            usdt.balanceOf(alice),
            principalPerToken + interestPerTokenInSecond * (endTs - startTs)
        );
    }

    function testBurnTokenWhenClaimAfterRepay() public {
        vm.warp(endTs + 100);
        couponBond.setRepaid(id);
        couponBond.claim(alice, id);

        assertEq(couponBond.balanceOf(alice, id), 0);
    }

    function testWithdrawResidue() public {
        uint256 withdrawAmount = 1e18; // arbitrary amount less than the balance of the coupondBond contract
        uint256 beforeBalance = couponBond.balanceOf(alice, id);

        // revert if not repaid
        vm.expectRevert(abi.encodeWithSignature("NotRepaid(uint256)", id));
        couponBond.withdrawResidue(id, withdrawAmount);

        // revert if too early
        couponBond.setRepaid(id);
        vm.expectRevert(abi.encodeWithSignature("EarlyWithdraw()"));
        couponBond.withdrawResidue(id, withdrawAmount);

        // Do Not burn user's unclaimed tokens
        vm.warp(endTs + 8 weeks);
        couponBond.withdrawResidue(id, withdrawAmount);
        uint256 afterBalance = couponBond.balanceOf(alice, id);
        assertEq(beforeBalance, afterBalance);

        // Check if usdt withdrawed.
        assertEq(usdt.balanceOf(owner), withdrawAmount);
    }
}
