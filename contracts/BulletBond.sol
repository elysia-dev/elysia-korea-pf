// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice This repays the interest & principal at once until the maturity date.
/// This contract has no need to The admin mint and sell NFT
contract BulletBond is ERC1155Supply, ERC1155Burnable, Ownable {
    using SafeERC20 for IERC20;

    error ZeroBalanceClaim();
    error EarlyClaim(address _from, uint256 _id);
    error ZeroBalanceWithdraw(uint256 _id);
    error EarlyWithdraw();
    error InvalidFinalValue();
    error NotRepaid(uint256 _id);

    struct Product {
        address token;
        uint256 value; // WAD, e.g. $100
        uint256 finalValue; // WAD
        string uri;
        uint64 startTs;
        uint64 endTs;
    }
    mapping(uint256 => Product) products;
    uint256 numProducts;

    constructor() ERC1155("") {}

    function addProduct(
        uint256 _initialSupply,
        address _token,
        uint256 _value,
        string memory _uri,
        uint64 _startTs,
        uint64 _endTs
    ) external onlyOwner {
        Product memory newProduct = Product({
            token: _token,
            value: _value,
            finalValue: 0,
            uri: _uri,
            startTs: _startTs,
            endTs: _endTs
        });
        products[numProducts] = newProduct;

        _mint(owner(), numProducts, _initialSupply, "");
        numProducts++;
    }

    // TODO: Q. Do weed need get function for product data?

    function uri(uint256 _id) public view override returns (string memory) {
        return products[_id].uri;
    }

    function setURI(uint256 _id, string memory _uri) external onlyOwner {
        products[_id].uri = _uri;
    }

    /// @notice Admin repays to let users claim. You can repay several times because all `_finalValue`s are summed up.
    function repay(
        uint256 _id,
        uint256 _finalValue,
        uint256 _totalFinalValue
    ) external {
        Product memory product = products[_id];
        if (_finalValue * totalSupply(_id) != _totalFinalValue)
            revert InvalidFinalValue();
        product.finalValue += _finalValue;

        IERC20(product.token).safeTransferFrom(
            _msgSender(),
            address(this),
            _totalFinalValue
        );
    }

    /// @notice Transfer the nft holder
    function claim(address _to, uint256 _id) external {
        Product memory product = products[_id];
        if (product.finalValue == 0) revert NotRepaid(_id);
        if (block.timestamp < product.endTs)
            revert EarlyClaim(_msgSender(), _id);

        uint256 balance = balanceOf(_to, _id);
        if (balance == 0) revert ZeroBalanceClaim();
        _burn(_to, _id, balance);

        uint256 receiveAmount = product.finalValue * balance;
        IERC20(product.token).safeTransfer(_to, receiveAmount);
    }

    /// @notice Admin withdraws the money to repay later when users do not claim for a long time.
    /// NOTE: Do not _burn to allow users claim later.
    function withdrawResidue(uint256 _id) external onlyOwner {
        Product memory product = products[_id];
        if (product.finalValue == 0) revert NotRepaid(_id);
        if (block.timestamp < product.endTs + 8 weeks) revert EarlyWithdraw();

        uint256 balance = totalSupply(_id);
        if (balance == 0) revert ZeroBalanceWithdraw(_id);

        uint256 withdrawAmount = product.finalValue * balance;
        IERC20(product.token).safeTransfer(owner(), withdrawAmount);
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
    }
}
