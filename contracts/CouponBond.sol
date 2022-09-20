// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice This repays the interest monthly. At the maturity date, lenders receive the principal and one-month interest.
contract CouponBond is
    ERC1155Supply,
    ERC1155Burnable,
    ERC1155Pausable,
    Ownable
{
    using SafeERC20 for IERC20;

    error ZeroBalanceClaim();
    error EarlyClaim(address _from, uint256 _id);
    error ZeroBalanceWithdraw(uint256 _id);
    error EarlyWithdraw();
    error InvalidFinalValue();
    error NotRepaid(uint256 _id);
    error AlreadyRepaid(uint256 _id);

    /// @param value        value per token in WAD, e.g. $100
    /// @param interestRate interest rate per token in second. WAD. e.g. 15%
    /// @param overdueRate  additional interest rate per token when overdue. WAD. e.g. 3% -> total 18% when overdue
    /// @param repaidBalance total amount of token repaid. decimal is the same with `token`.
    struct Product {
        address token;
        uint256 value;
        uint256 interestRate;
        uint256 overdueRate;
        string uri;
        uint256 tokenBalance;
        uint64 startTs;
        uint64 endTs;
        uint64 repaidTs;
    }
    mapping(uint256 => Product) public products;
    uint256 public numProducts;

    mapping(uint256 => mapping(address => uint256)) public lastUpdatedTs;
    mapping(uint256 => mapping(address => uint256)) public unclaimedInterest;

    constructor() ERC1155("") Pausable() {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addProduct(
        uint256 _initialSupply,
        address _token,
        uint256 _value,
        uint256 _interestRate,
        uint256 _overdueRate,
        string memory _uri,
        uint64 _startTs,
        uint64 _endTs
    ) external onlyOwner {
        Product memory newProduct = Product({
            token: _token,
            value: _value,
            interestRate: _interestRate,
            overdueRate: _overdueRate,
            uri: _uri,
            tokenBalance: 0,
            startTs: _startTs,
            endTs: _endTs,
            repaidTs: 0
        });
        products[numProducts] = newProduct;

        _mint(owner(), numProducts, _initialSupply, "");
        numProducts++;
    }

    function uri(uint256 _id) public view override returns (string memory) {
        return products[_id].uri;
    }

    function setURI(uint256 _id, string memory _uri) external onlyOwner {
        products[_id].uri = _uri;
    }

    function isRepaid(uint256 _id) public view returns (bool) {
        return products[_id].repaidTs != 0;
    }

    /// @dev It is not able to repay after fully repaying the loan.
    /// The caller need to approve the repaying token.
    /// There are 3 cases.
    /// 1. block.timestamp < startTimestamp: repay only the principal.
    /// 2. startTs <= block.timestamp <= endTs: repay principal + interest
    /// 3. endTs < block.timestamp: repay principal + interest + overdue interest
    /// @param _id token id
    /// @param _amount amount of token to repay. type(uint256).max means to repay all.
    function repay(uint256 _id, uint256 _amount) external {
        Product storage product = products[_id];
        uint256 repayingAmount = _amount;

        if (isRepaid(_id)) revert AlreadyRepaid(_id);

        uint256 unpaidDebt = getUnpaidDebt(_id);
        if (_amount == type(uint256).max) {
            repayingAmount = unpaidDebt;
        }

        product.tokenBalance += repayingAmount;
        if (unpaidDebt <= product.tokenBalance) {
            product.repaidTs = uint64(block.timestamp);
        }

        IERC20(product.token).safeTransferFrom(
            msg.sender,
            address(this),
            repayingAmount
        );
    }

    function getUnitDebt(uint256 _id) public view returns (uint256) {
        Product storage product = products[_id];
        uint256 ts = 0;

        if (isRepaid(_id)) {
            ts = product.repaidTs;
        } else if (block.timestamp < product.startTs) {
            ts = product.startTs; // just set interest as 0
        } else {
            ts = block.timestamp;
        }

        uint256 interest = product.interestRate * (ts - product.startTs);

        // Overdue
        if (product.endTs < ts) {
            interest += product.overdueRate * (ts - product.endTs);
        }

        return (product.value + interest);
    }

    function getUnpaidDebt(uint256 _id) public view returns (uint256) {
        Product storage product = products[_id];
        // NOTE: ERC-1155 totalSupply has no decimal.
        return totalSupply(_id) * getUnitDebt(_id) - product.tokenBalance;
    }

    /// @notice Nft holders claim their interest.
    /// NOTE: Users with zero balance are also able to claim.
    function claim(address _to, uint256 _id) external whenNotPaused {
        Product storage product = products[_id];
        uint256 receiveAmount;

        _updateInterest(_to, _id);

        if (product.endTs <= block.timestamp && isRepaid(_id)) {
            uint256 balance = balanceOf(_to, _id);

            // Both interest & principal
            receiveAmount =
                (product.value * balance) +
                unclaimedInterest[_id][_to];

            _burn(_to, _id, 1);
        } else {
            // only interest
            receiveAmount = unclaimedInterest[_id][_to];
        }

        unclaimedInterest[_id][_to] = 0;
        lastUpdatedTs[_id][_to] = block.timestamp;

        product.tokenBalance -= receiveAmount;
        IERC20(product.token).safeTransfer(_to, receiveAmount);
    }

    /*
    /// @notice Admin withdraws the money to repay later when users do not claim for a long time.
    /// @param _id token id
    /// @param _amount the amount of token to withdraw
    /// NOTE: Do not _burn to allow users claim later.
    function withdrawResidue(uint256 _id, uint256 _amount) external onlyOwner {
        Product storage product = products[_id];
        if (!isRepaid(_id)) revert NotRepaid(_id);
        if (block.timestamp < product.endTs + 8 weeks) revert EarlyWithdraw();

        uint256 balance = totalSupply(_id);
        if (balance == 0) revert ZeroBalanceWithdraw(_id);

        product.tokenBalance -= _amount;
        IERC20(product.token).safeTransfer(owner(), _amount);
    }
    */

    function getInterest(address _to, uint256 _id)
        public
        view
        returns (uint256)
    {
        Product storage product = products[_id];
        if (product.startTs < 0) return 0;
        uint256 userLastUpdatedTs = lastUpdatedTs[_id][_to];

        return
            unclaimedInterest[_id][_to] +
            _calculateInterest(
                product.interestRate,
                product.overdueRate,
                userLastUpdatedTs,
                product.endTs,
                block.timestamp
            );
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Supply, ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                _updateInterest(from, id);
            }
        }

        if (to != address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                _updateInterest(to, id);
            }
        }
    }

    function _updateInterest(address _to, uint256 _id) internal {
        Product storage product = products[_id];
        if (block.timestamp <= product.startTs) return;

        uint256 userLastUpdatedTs = lastUpdatedTs[_id][_to];
        if (userLastUpdatedTs == 0) {
            userLastUpdatedTs = product.startTs;
        }

        unclaimedInterest[_id][_to] +=
            balanceOf(_to, _id) *
            _calculateInterest(
                product.interestRate,
                product.overdueRate,
                userLastUpdatedTs,
                product.endTs,
                block.timestamp
            );
        lastUpdatedTs[_id][_to] = block.timestamp;
    }

    function _calculateInterest(
        uint256 _rateInSecond,
        uint256 _overdueRateInSecond,
        uint256 _lastUpdatedTs,
        uint256 _endTs,
        uint256 _currentTs
    ) internal pure returns (uint256) {
        uint256 timeDelta = _currentTs - _lastUpdatedTs;
        uint256 interest = _rateInSecond * timeDelta;
        if (_endTs < _currentTs) {
            uint256 latest = _endTs > _lastUpdatedTs ? _endTs : _lastUpdatedTs;
            interest += _overdueRateInSecond * (_currentTs - latest);
        }

        return interest;
    }
}
