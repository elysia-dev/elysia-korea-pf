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
    uint256 interestRate = (principalPerToken * 30) / (100 * (endTs - startTs));
    uint256 overdueRate = (principalPerToken * 3) / (100 * 365 days);
    uint256 totalSupply = 1000;

    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);

    uint256 aliceBalance = 1;
    uint256 bobBalance = 100;

    function setUp() public {
        vm.startPrank(owner);
        usdt = new MockERC20();

        couponBond = new CouponBond();
        couponBond.addProduct(
            totalSupply,
            address(usdt),
            principalPerToken, // bsc USDT or BUSD both use decimal 18, each token are worth $100.
            interestRate,
            overdueRate,
            "ipfs://testuri",
            startTs,
            endTs
        );

        couponBond.safeTransferFrom(owner, alice, id, aliceBalance, "");
        couponBond.safeTransferFrom(owner, bob, id, bobBalance, "");
    }

    // N seconds elapsed but it's still before endTs -> claim
    function testClaimBeforeRepay(uint64 elapsed) public {
        vm.assume(elapsed <= endTs - startTs);
        vm.warp(startTs + elapsed);

        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, type(uint256).max);

        couponBond.claim(alice, id);

        assertEq(usdt.balanceOf(alice), interestRate * elapsed); // interest transferred
        assertEq(couponBond.balanceOf(alice, id), aliceBalance); // Not burned

        couponBond.claim(alice, id);
        assertEq(usdt.balanceOf(alice), interestRate * elapsed); // No duplicate interest
    }

    // The time elapses after endTs -> claim -> repay all -> claim
    function testClaimBeforeAndAfterRepay(uint64 elapsed) public {
        vm.assume(elapsed <= 1000000); // no invalid timestamp
        vm.warp(endTs + elapsed);

        // 1. claim before repay
        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, 30000 * 1e18); // repay only some interest
        couponBond.claim(alice, id);

        uint256 overdueInterest = 0;
        if (endTs < block.timestamp) {
            overdueInterest = overdueRate * (block.timestamp - endTs);
        }
        uint256 totalInterest = interestRate *
            (block.timestamp - startTs) +
            overdueInterest;

        // receive only interest
        assertEq(usdt.balanceOf(alice), totalInterest);

        // 2. claim after repay
        couponBond.repay(id, type(uint256).max);
        couponBond.claim(alice, id);

        assertEq(usdt.balanceOf(alice), principalPerToken + totalInterest);
    }

    // FIXME: this causes an underflow error.
    // repay하고 나면 claim했을 때 burn 되어 product.repaidBalance 가 더 커지는 문제
    // test: repay all -> claim -> repay all
    function testRepayTwice() public {}

    function testBurnTokenWhenClaimAfterRepay() public {
        vm.warp(endTs + 100);
        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, type(uint256).max);

        couponBond.claim(alice, id);

        assertEq(couponBond.balanceOf(alice, id), 0);
    }

    function testRepayBeforeStart() public {
        // TODO: just repay the principal;
    }

    function testRepayGivenAmount() public {
        uint256 repayingAmount = 1e18;
        usdt.approve(address(couponBond), type(uint256).max);
        console2.log("owner usdt balance: %d", usdt.balanceOf(owner));
        couponBond.repay(id, repayingAmount);

        assertEq(usdt.balanceOf(address(couponBond)), repayingAmount);
    }

    function testRepayBeforeStartTs() public {
        // TODO: repay before startTs
    }

    function testRepayBeforeEndTs() public {}

    function testRepayGivenUintMax() public {
        // TODO: everybody claims
        // Check if it is the same with the below.
        // usdt.transfer(address(couponBond), 130 * 1000 * 1e18); // 30% interest i.e. $100 -> $130
    }

    function testOverdueRepay() public {
        // TODO: everybody claims
    }

    function testWithdrawResidue() public {
        uint256 withdrawAmount = 1e18; // arbitrary amount less than the balance of the coupondBond contract
        uint256 beforeBalance = couponBond.balanceOf(alice, id);

        // revert if not repaid
        vm.expectRevert(abi.encodeWithSignature("NotRepaid(uint256)", id));
        couponBond.withdrawResidue(id, withdrawAmount);

        // revert if too early
        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, type(uint256).max);
        vm.expectRevert(abi.encodeWithSignature("EarlyWithdraw()"));
        couponBond.withdrawResidue(id, withdrawAmount);

        // Action
        vm.warp(endTs + 8 weeks);
        uint256 usdtBeforeBalance = usdt.balanceOf(owner);
        couponBond.withdrawResidue(id, withdrawAmount);

        // Do Not burn user's unclaimed tokens
        uint256 afterBalance = couponBond.balanceOf(alice, id);
        assertEq(beforeBalance, afterBalance);

        // Check if usdt withdrawed.
        assertEq(usdt.balanceOf(owner), withdrawAmount + usdtBeforeBalance);
    }

    // TODO: Test getUnitDebt: 3가지 케이스

    // TODO: Test getUnpaidDebt
}
