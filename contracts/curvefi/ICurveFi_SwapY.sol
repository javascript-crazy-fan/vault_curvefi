// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.10;

/**
 * @dev Interface for Curve.Fi swap contract for Y-pool.
 * @dev See original implementation in official repository:
 * https://github.com/curvefi/curve-contract/blob/master/contracts/pools/y/StableSwapY.vy
 */
interface ICurveFi_SwapY {
    function add_liquidity(uint256 amounts, uint256 min_mint_amount) external;

    function remove_liquidity(uint256 _amount, uint256 min_amounts) external;

    function remove_liquidity_imbalance(
        uint256 amounts,
        uint256 max_burn_amount
    ) external;

    function calc_token_amount(uint256 amounts, bool deposit)
        external
        view
        returns (uint256);

    function balances(address) external view returns (uint256);

    function coins(address) external view returns (address);
}
