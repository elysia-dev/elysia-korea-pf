// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/WadRayMath.sol";

/// @notice This repays the interest monthly. At the maturity date, lenders receive the principal and one-month interest.
contract CouponBond is ERC1155Supply, ERC1155Burnable, Ownable {
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;

    error ZeroBalanceClaim();
    error EarlyClaim(address _from, uint256 _id);
    error ZeroBalanceWithdraw(uint256 _id);
    error EarlyWithdraw();
    error InvalidFinalValue();
    error NotRepaid(uint256 _id);

    struct Product {
        address token;
        uint256 value; // WAD, e.g. $100
        uint256 interestPerTokenInSecond; // WAD
        string uri;
        bool repaid;
        uint64 startTs;
        uint64 endTs;
    }
    mapping(uint256 => Product) public products;
    uint256 public numProducts;

    mapping(uint256 => mapping(address => uint256)) public lastUpdatedTs;
    mapping(uint256 => mapping(address => uint256)) public unclaimedInterest;

    constructor() ERC1155("") {}

    function addProduct(
        uint256 _initialSupply,
        address _token,
        uint256 _value,
        uint256 _interestPerTokenInSecond,
        string memory _uri,
        uint64 _startTs,
        uint64 _endTs
    ) external onlyOwner {
        Product memory newProduct = Product({
            token: _token,
            value: _value,
            interestPerTokenInSecond: _interestPerTokenInSecond,
            uri: _uri,
            repaid: false,
            startTs: _startTs,
            endTs: _endTs
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

    function setRepaid(uint256 _id) external onlyOwner {
        products[_id].repaid = true;
    }

    /// @notice Nft holders claim their interest.
    /// NOTE: Users with zero balance are also able to claim.
    function claim(address _to, uint256 _id) external {
        Product memory product = products[_id];

        _updateInterest(_to, _id);

        if (product.endTs < block.timestamp && product.repaid) {
            uint256 balance = balanceOf(_to, _id);

            // Both interest & principal
            uint256 receiveAmount = (product.value * balance) +
                unclaimedInterest[_id][_to];

            unclaimedInterest[_id][_to] = 0;
            lastUpdatedTs[_id][_to] = block.timestamp;

            // burn
            _burn(_to, _id, balance);

            IERC20(product.token).safeTransfer(_to, receiveAmount);
        } else {
            // only interest
            uint256 receiveAmount = unclaimedInterest[_id][_to];

            unclaimedInterest[_id][_to] = 0;
            lastUpdatedTs[_id][_to] = block.timestamp;

            IERC20(product.token).safeTransfer(_to, receiveAmount);
        }
    }

    /// @notice Admin withdraws the money to repay later when users do not claim for a long time.
    /// NOTE: Do not _burn to allow users claim later.
    function withdrawResidue(uint256 _id, uint256 _amount) external onlyOwner {
        Product memory product = products[_id];
        if (!product.repaid) revert NotRepaid(_id);
        if (block.timestamp < product.endTs + 8 weeks) revert EarlyWithdraw();

        uint256 balance = totalSupply(_id);
        if (balance == 0) revert ZeroBalanceWithdraw(_id);

        IERC20(product.token).safeTransfer(owner(), _amount);
    }

    function getInterest(address _to, uint256 _id)
        public
        view
        returns (uint256)
    {
        Product memory product = products[_id];
        if (product.startTs < 0) return 0;
        uint256 userLastUpdatedTs = lastUpdatedTs[_id][_to];

        return
            unclaimedInterest[_id][_to] +
            _calculateInterest(
                product.interestPerTokenInSecond,
                userLastUpdatedTs,
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
    ) internal virtual override(ERC1155, ERC1155Supply) {
        // Use ERC1155Supply._beforeTokenTransfer
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
        Product memory product = products[_id];
        if (block.timestamp <= product.startTs) return;

        uint256 rate = product.interestPerTokenInSecond;
        uint256 userLastUpdatedTs = lastUpdatedTs[_id][_to];
        if (userLastUpdatedTs == 0) {
            userLastUpdatedTs = product.startTs;
        }

        uint256 currentTs = block.timestamp;
        if (product.endTs < currentTs) {
            currentTs = product.endTs;
        }

        unclaimedInterest[_id][_to] +=
            balanceOf(_to, _id) *
            _calculateInterest(rate, userLastUpdatedTs, currentTs);
        lastUpdatedTs[_id][_to] = block.timestamp;
    }

    /// @param _rateInSecond RAY
    function _calculateInterest(
        uint256 _rateInSecond,
        uint256 _lastUpdatedTs,
        uint256 _currentTs
    ) internal pure returns (uint256) {
        uint256 timeDelta = _currentTs - _lastUpdatedTs;
        return _rateInSecond * timeDelta;
    }
}
