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
    uint256 interestPerTokenInSecond =
        (100 * 1e18 * 3) / (10 * (endTs - startTs));

    uint256 principalPerToken = 100 * 1e18;
    uint256 totalSupply = 1000;

    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        usdt = new MockERC20();
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
        uint256 ownerUSDT = usdt.balanceOf(owner);
        emit log_named_uint("Owner's USDT balance:", ownerUSDT);

        usdt.transfer(address(couponBond), 130 * 1000 * 1e18); // 30% interest i.e. $100 -> $130
        couponBond.safeTransferFrom(owner, alice, id, 1, "");
    }

    // 100 seconds elapsed -> claim
    function testClaimBeforeRepay() public {
        uint64 elapsed = 100;
        vm.warp(startTs + elapsed);

        couponBond.claim(alice, id);

        assertEq(usdt.balanceOf(alice), interestPerTokenInSecond * elapsed);
    }

    // pass after endTs -> claim -> setRepaid -> claim
    function testClaimTwice() public {
        vm.warp(endTs + 100);

        // 1. claim before repay
        couponBond.claim(alice, id);

        assertEq(
            usdt.balanceOf(alice),
            interestPerTokenInSecond * (endTs - startTs)
        );

        // 2. claim after repay
        couponBond.setRepaid(0);
        couponBond.claim(alice, id);

        assertEq(
            usdt.balanceOf(alice),
            principalPerToken + interestPerTokenInSecond * (endTs - startTs)
        );
    }
}
