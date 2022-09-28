// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "../lib/forge-std/src/console2.sol";

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

    /// @param value                    value per token in WAD, e.g. $100
    /// @param interestPerSecond        interest rate per token in second. WAD. e.g. 15%
    /// @param overdueInterestPerSecond additional interest rate per token when overdue. WAD. e.g. 3% -> total 18% when overdue
    /// @param totalRepaid              total amount of token repaid. decimal is the same with `token`.
    struct Product {
        address token;
        uint256 value;
        uint256 interestPerSecond;
        uint256 overdueInterestPerSecond;
        string uri;
        uint256 totalRepaid;
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
        uint256 _interestPerSecond,
        uint256 _overdueInterestPerSecond,
        string memory _uri,
        uint64 _startTs,
        uint64 _endTs
    ) external onlyOwner {
        Product memory newProduct = Product({
            token: _token,
            value: _value,
            interestPerSecond: _interestPerSecond,
            overdueInterestPerSecond: _overdueInterestPerSecond,
            uri: _uri,
            totalRepaid: 0,
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

        product.totalRepaid += repayingAmount;

        if (getTotalDebt(_id) <= product.totalRepaid) {
            product.repaidTs = uint64(block.timestamp);
        }

        IERC20(product.token).safeTransferFrom(
            _msgSender(),
            address(this),
            repayingAmount
        );
    }

    /// @notice Nft holders claim their interest.
    /// NOTE: Users with zero balance are also able to claim.
    function claim(address _to, uint256 _id) external whenNotPaused {
        Product storage product = products[_id];
        uint256 receiveAmount;

        _updateInterest(_to, _id);

        if (isRepaid(_id)) {
            uint256 balance = balanceOf(_to, _id);

            // Both interest & principal
            receiveAmount =
                (product.value * balance) +
                unclaimedInterest[_id][_to];

            _burn(_to, _id, balance);
        } else {
            // only interest
            receiveAmount = unclaimedInterest[_id][_to];
        }

        unclaimedInterest[_id][_to] = 0;
        lastUpdatedTs[_id][_to] = block.timestamp;

        IERC20(product.token).safeTransfer(_to, receiveAmount);
    }

    /// @dev ERC-1155 totalSupply has no decimal. Therefore, just multiply totalSupply * debt per token
    function getTotalDebt(uint256 _id) public view returns (uint256) {
        return totalSupply(_id) * getUnitDebt(_id);
    }

    /// @notice The debt does not increase after repaid.
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

        uint256 interest = product.interestPerSecond * (ts - product.startTs);

        // Overdue
        if (product.endTs < ts) {
            interest += product.overdueInterestPerSecond * (ts - product.endTs);
        }

        return (product.value + interest);
    }

    function getUnpaidDebt(uint256 _id) public view returns (uint256) {
        Product storage product = products[_id];
        return getTotalDebt(_id) - product.totalRepaid;
    }

    function getInterest(address _to, uint256 _id)
        public
        view
        returns (uint256)
    {
        return unclaimedInterest[_id][_to] + _getAdditionalInterest(_to, _id);
    }

    // ****** internal ****** //

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

    function _getAdditionalInterest(address _to, uint256 _id)
        internal
        view
        returns (uint256)
    {
        Product storage product = products[_id];
        if (block.timestamp <= product.startTs) return 0;

        uint256 userLastUpdatedTs = lastUpdatedTs[_id][_to];
        uint256 currentTs = block.timestamp;

        if (userLastUpdatedTs < product.startTs) {
            userLastUpdatedTs = product.startTs;
        }

        if (isRepaid(_id)) {
            currentTs = product.repaidTs;
        }

        return
            balanceOf(_to, _id) *
            _calculateInterest(
                product.interestPerSecond,
                product.overdueInterestPerSecond,
                userLastUpdatedTs,
                product.endTs,
                currentTs
            );
    }

    /// @notice Save the current unclaimed interest and the updated timestamp.
    function _updateInterest(address _to, uint256 _id) internal {
        unclaimedInterest[_id][_to] = getInterest(_to, _id);
        lastUpdatedTs[_id][_to] = block.timestamp;
    }

    function _calculateInterest(
        uint256 _interestPerSecond,
        uint256 _overdueInterestPerSecond,
        uint256 _lastUpdatedTs,
        uint256 _endTs,
        uint256 _currentTs
    ) internal pure returns (uint256) {
        uint256 timeDelta = _currentTs - _lastUpdatedTs;
        uint256 interest = _interestPerSecond * timeDelta;
        if (_endTs < _currentTs) {
            uint256 latest = _endTs > _lastUpdatedTs ? _endTs : _lastUpdatedTs;
            interest += _overdueInterestPerSecond * (_currentTs - latest);
        }

        return interest;
    }
}
