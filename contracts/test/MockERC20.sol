// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Binance-Peg BSC-USD", "BNB_USDT") {
        faucet(1000000 * 10**28);
    }

    function faucet(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}
