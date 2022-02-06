// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.10;

/**
 * @dev Interface for Curve.Fi deposit contract for Y-pool.
 * @dev See original implementation in official repository:
 * https://github.com/curvefi/curve-contract/blob/master/contracts/pools/y/DepositY.vy
 */
interface ICurveFi_DepositY {
    function add_liquidity(uint256 uamounts, uint256 min_mint_amount) external;

    function remove_liquidity(uint256 _amount, uint256 min_uamounts) external;

    function remove_liquidity_imbalance(
        uint256 uamounts,
        uint256 max_burn_amount
    ) external;

    function coins(uint256 i) external view returns (address);

    function underlying_coins(uint256 i) external view returns (address);

    function underlying_coins() external view returns (address);

    function curve() external view returns (address);

    function token() external view returns (address);
}
