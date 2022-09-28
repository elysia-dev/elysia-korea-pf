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
    uint256 interestPerSecond =
        (principalPerToken * 30) / (100 * (endTs - startTs));
    uint256 overdueInterestPerSecond =
        (principalPerToken * 3) / (100 * 365 days);
    uint256 totalSupply = 1000;

    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);

    mapping(address => uint256) balances;
    mapping(address => uint256) interests;

    function _everybodyClaims() internal {
        // Everybody claims
        changePrank(alice);
        // console2.log("alice bond balance: ", couponBond.balanceOf(alice, id));
        couponBond.claim(alice, id);
        // console2.log("balance: ", usdt.balanceOf(address(couponBond)));

        changePrank(bob);
        // console2.log("bob bond balance: ", couponBond.balanceOf(bob, id));
        couponBond.claim(bob, id);
        // console2.log("balance: ", usdt.balanceOf(address(couponBond)));

        changePrank(owner);
        couponBond.claim(owner, id);
        // console2.log("balance: ", usdt.balanceOf(address(couponBond)));

        changePrank(owner);
    }

    function setUp() public {
        balances[alice] = 1;
        balances[bob] = 100;
        balances[owner] = totalSupply - balances[alice] - balances[bob];

        vm.startPrank(owner);
        usdt = new MockERC20();

        couponBond = new CouponBond();
        couponBond.addProduct(
            totalSupply,
            address(usdt),
            principalPerToken, // bsc USDT or BUSD both use decimal 18, each token are worth $100.
            interestPerSecond,
            overdueInterestPerSecond,
            "ipfs://testuri",
            startTs,
            endTs
        );

        assertEq(couponBond.totalSupply(id), totalSupply);

        couponBond.safeTransferFrom(owner, alice, id, balances[alice], "");
        couponBond.safeTransferFrom(owner, bob, id, balances[bob], "");
    }

    // ********** Claim ********** //

    // N seconds elapsed but it's still before endTs -> claim
    function testClaimBeforeRepayAll(uint64 elapsed) public {
        vm.assume(elapsed <= endTs - startTs);
        vm.warp(startTs + elapsed);

        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, 30000 * 1e18); // repay only some interest

        couponBond.claim(alice, id);

        assertEq(usdt.balanceOf(alice), interestPerSecond * elapsed); // interest transferred
        assertEq(couponBond.balanceOf(alice, id), balances[alice]); // Not burned

        couponBond.claim(alice, id);
        assertEq(usdt.balanceOf(alice), interestPerSecond * elapsed); // No duplicate interest
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
            overdueInterest =
                overdueInterestPerSecond *
                (block.timestamp - endTs);
        }
        uint256 totalInterest = interestPerSecond *
            (block.timestamp - startTs) +
            overdueInterest;

        // receive only interest
        assertEq(usdt.balanceOf(alice), totalInterest);

        // 2. claim after repay
        couponBond.repay(id, type(uint256).max);
        couponBond.claim(alice, id);

        assertEq(usdt.balanceOf(alice), principalPerToken + totalInterest);
    }

    function testBurnTokenWhenClaimAfterRepay() public {
        vm.warp(endTs + 100);
        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, type(uint256).max);

        couponBond.claim(alice, id);

        assertEq(couponBond.balanceOf(alice, id), 0);
        assertEq(couponBond.totalSupply(id), totalSupply - balances[alice]);
    }

    function testRepayAllBeforeEndTs(uint32 elapsed) public {
        uint64 currentTs = startTs + elapsed;
        vm.assume(currentTs < endTs);
        vm.warp(currentTs);
        uint256 totalDebt = principalPerToken * totalSupply;
        uint256 duration = currentTs - startTs;

        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, type(uint256).max);
        deal(address(usdt), owner, 0); // set the owner's usdt balance as 0

        _everybodyClaims();
        interests[alice] = interestPerSecond * duration * balances[alice];
        interests[bob] = interestPerSecond * duration * balances[bob];
        interests[owner] = interestPerSecond * duration * balances[owner];

        assertEq(
            usdt.balanceOf(alice),
            interests[alice] + balances[alice] * principalPerToken
        );
        assertEq(
            usdt.balanceOf(bob),
            interests[bob] + balances[bob] * principalPerToken
        );
        assertEq(
            usdt.balanceOf(owner),
            interests[owner] + balances[owner] * principalPerToken
        );
        assertEq(usdt.balanceOf(address(couponBond)), 0);
    }

    // Check the interest is added when overdue
    function testOverdueRepay(uint64 overdue) public {
        vm.assume(overdue < type(uint64).max - endTs);
        vm.warp(endTs + overdue);
        uint64 currentTs = endTs + overdue;
        uint256 duration = endTs - currentTs;
        uint256 totalDebt = principalPerToken * totalSupply;

        /*
        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, ?);
        assertTrue(couponBond.isRepaid(id))

        deal(address(usdt), owner, 0); // set the owner's usdt balance as 0

        _everybodyClaims();
        interests[alice] = interestPerSecond * duration * balances[alice];
        interests[bob] = interestPerSecond * duration * balances[bob];
        interests[owner] = interestPerSecond * duration * balances[owner];

        assertEq(
            usdt.balanceOf(alice),
            interests[alice] + balances[alice] * principalPerToken
        );
        assertEq(
            usdt.balanceOf(bob),
            interests[bob] + balances[bob] * principalPerToken
        );
        assertEq(
            usdt.balanceOf(owner),
            interests[owner] + balances[owner] * principalPerToken
        );

        _everybodyClaims();
        */
    }

    // ********** Repay ********** //

    // Scenario: repay all -> claim -> repay all
    function testRepayTwice(uint64 elapsed) public {
        vm.assume(elapsed <= 36500 days); // no invalid timestamp
        vm.warp(endTs + elapsed);

        // 1. repay all
        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, type(uint256).max);

        // 2. claim: burn alice's tokens
        couponBond.claim(alice, id);

        // 3. repay all
        vm.expectRevert(abi.encodeWithSignature("AlreadyRepaid(uint256)", id));
        couponBond.repay(id, type(uint256).max);
    }

    function testRepayAllBeforeStart() public {
        vm.warp(startTs - 100);
        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, type(uint256).max);

        assertEq(
            usdt.balanceOf(address(couponBond)),
            totalSupply * principalPerToken
        );

        _everybodyClaims();
    }

    // Check: Update product.tokenBalance
    function testRepayGivenAmount() public {
        vm.warp(startTs + 100);
        uint256 repayingAmount = 1e18;

        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, repayingAmount);

        (, , , , , uint256 tokenBalance, , , ) = couponBond.products(id);

        assertEq(usdt.balanceOf(address(couponBond)), repayingAmount);
        assertEq(usdt.balanceOf(address(couponBond)), tokenBalance);
    }

    // ********** getInterest ********** //

    // Given 0 < lastUpdatedTs <= startTs
    function testGetInterestBeforeStart(uint64 currentTs) public {
        vm.warp(2); // timestamp 1 is used in setUp
        changePrank(alice);
        couponBond.safeTransferFrom(alice, alice, id, 1, ""); // Update lastUpdatedTs
        assertEq(couponBond.lastUpdatedTs(id, alice), 2);
        changePrank(owner);

        vm.assume(2 <= currentTs && currentTs <= startTs); // no invalid timestamp
        vm.warp(currentTs);
        assertEq(couponBond.getInterest(alice, id), 0);
    }

    function testGetInterestAfterStart(uint32 elapsed) public {
        vm.assume(startTs + elapsed < endTs);
        vm.warp(startTs + elapsed);
        uint256 interest = interestPerSecond * elapsed;
        assertEq(couponBond.getInterest(alice, id), interest);
    }

    // Overdue
    function testGetInterestAfterEnd(uint64 overdue) public {
        vm.assume(overdue < type(uint64).max - endTs);
        vm.warp(endTs + overdue);
        uint64 elapsed = endTs + overdue - startTs;
        uint256 interest = interestPerSecond *
            elapsed +
            overdueInterestPerSecond *
            overdue;
        assertEq(couponBond.getInterest(alice, id), interest);
    }

    // Should return only unclaimed interest
    function testGetInterestAfterClaimOnce(uint64 currentTs) public {}

    // ********** getUnitDebt ********** //
    // TODO: Test getUnitDebt: 3가지 케이스
    function testGetUnitDebt() public {
        // getUnitDebt(id);
    }

    // ********** getUnpaidDebt ********** //
    // TODO: Test getUnpaidDebt
    function testGetUnpaidDebt() public {
        // TODO: Check the result does not increase after claim
        uint256 elapsed = 7;
        vm.warp(startTs + 7);
        usdt.approve(address(couponBond), type(uint256).max);
        couponBond.repay(id, 30000 * 1e18); // repay only some interest

        uint256 debtBefore = couponBond.getUnpaidDebt(id);
        console.log("debtBefore: ", debtBefore);

        couponBond.claim(alice, id);

        uint256 debtAfter = couponBond.getUnpaidDebt(id);
        console.log("debtAfter: ", debtAfter);
    }

    /*
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
    */
}
