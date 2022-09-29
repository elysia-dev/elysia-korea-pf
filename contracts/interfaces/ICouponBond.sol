// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

interface ICouponBond {
    /// @param token                    the token borrowed and to be repaid.
    /// @param value                    value per token in WAD, e.g. $100
    /// @param interestPerSecond        interest rate per token in second. WAD. e.g. 15%
    /// @param overdueInterestPerSecond additional interest rate per token when overdue. WAD. e.g. 3% -> total 18% when overdue
    /// @param uri                      uri for the product
    /// @param totalRepaid              total amount of token repaid. decimal is the same with `token`.
    /// @param startTs                  when the loan starts
    /// @param endTs                    when the loan should be repaid
    /// @param repaidTs                 when the loan is actually repaid
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

    function addProduct(
        uint256 _initialSupply,
        address _token,
        uint256 _value,
        uint256 _interestPerSecond,
        uint256 _overdueInterestPerSecond,
        string memory _uri,
        uint64 _startTs,
        uint64 _endTs
    ) external;

    /// @dev It is not able to repay after fully repaying the loan.
    /// The caller need to approve the repaying token.
    /// There are 3 cases.
    /// 1. block.timestamp < startTimestamp: repay only the principal.
    /// 2. startTs <= block.timestamp <= endTs: repay principal + interest
    /// 3. endTs < block.timestamp: repay principal + interest + overdue interest
    /// @param _id token id
    /// @param _amount amount of token to repay. type(uint256).max means to repay all.
    function repay(uint256 _id, uint256 _amount) external;

    /// @notice Nft holders claim their interest.
    /// Users with zero balance are also able to claim because they once had it,
    /// but may have transferred.
    function claim(address _to, uint256 _id) external;

    // ********** view ********** //
    /// @notice Show whether the loan is repaid.
    function isRepaid(uint256 _id) external view returns (bool);

    /// @return whether the loan is repaid, unit debt, unclaimed interest
    function getDebtInfo(uint256 _id, address _lender)
        external
        view
        returns (
            bool,
            uint256,
            uint256
        );

    /// @notice Calculate the total debt regardless of the repaid amount.
    function getTotalDebt(uint256 _id) external view returns (uint256);

    /// @notice Calculate the debt value if it has never been claimed.
    /// It does not increase after repaid.
    function getUnitDebt(uint256 _id) external view returns (uint256);

    /// @notice Calculate unclaimed interest
    function getUnclaimedInterest(address _to, uint256 _id)
        external
        view
        returns (uint256);

    /// @notice Calculate the debt value to be fully repaid.
    function getUnpaidDebt(uint256 _id) external view returns (uint256);
}
