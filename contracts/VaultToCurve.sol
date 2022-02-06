// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.10;

import "@openzeppelin/upgrades-core/contracts/Initializable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./curvefi/ICurveFi_DepositY.sol";
import "./curvefi/ICurveFi_Gauge.sol";
import "./curvefi/ICurveFi_Minter.sol";
import "./curvefi/ICurveFi_SwapY.sol";
import "./curvefi/IYERC20.sol";

contract VaultToCurve is Initializable, Context, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public curveFi_Deposit;
    address public curveFi_Swap;
    address public curveFi_LPToken;
    address public curveFi_LPGauge;
    address public curveFi_CRVMinter;
    address public curveFi_CRVToken;
    uint256 public exchange_rate_between_DAI_and_LPToken;

    /**
     * @notice Set CurveFi contracts addresses
     * @param _depositContract CurveFi Deposit contract for Y-pool
     * @param _gaugeContract CurveFi Gauge contract for Y-pool
     * @param _minterContract CurveFi CRV minter
     */
    function setUp(
        address _depositContract,
        address _gaugeContract,
        address _minterContract
    ) external onlyOwner {
        require(
            _depositContract != address(0),
            "Incorrect deposit contract address"
        );

        curveFi_Deposit = _depositContract;
        curveFi_Swap = ICurveFi_DepositY(curveFi_Deposit).curve();
        curveFi_LPGauge = _gaugeContract;
        curveFi_LPToken = ICurveFi_DepositY(curveFi_Deposit).token();

        require(
            ICurveFi_Gauge(curveFi_LPGauge).lp_token() ==
                address(curveFi_LPToken),
            "CurveFi LP tokens do not match"
        );

        curveFi_CRVMinter = _minterContract;
        curveFi_CRVToken = ICurveFi_Gauge(curveFi_LPGauge).crv_token();
    }

    /**
     * @notice Deposits DAI and receive LP tokens
     * @param underlyingAmount amounts to be deposited
     */
    function deposit(uint256 underlyingAmount) public {
        address stableCoin = ICurveFi_DepositY(curveFi_Deposit)
            .underlying_coins();
        require(
            IERC20(stableCoin).balanceOf(_msgSender()) >= underlyingAmount,
            "Charge more."
        );
        IERC20(stableCoin).safeTransferFrom(
            _msgSender(),
            address(this),
            underlyingAmount
        );
        IERC20(stableCoin).safeApprove(curveFi_Deposit, underlyingAmount);

        ICurveFi_DepositY(curveFi_Deposit).add_liquidity(underlyingAmount, 0);

        uint256 LpTokenAmount = IERC20(curveFi_LPToken).balanceOf(
            address(this)
        );
        IERC20(curveFi_LPToken).safeTransfer(_msgSender(), LpTokenAmount);

        // Update exchange Rate between DAI and LP Token
        exchange_rate_between_DAI_and_LPToken = underlyingAmount
            .div(LpTokenAmount)
            .mul(100);
    }

    /**
     * @notice Withdraws stablecoins (registered in Curve.Fi Y pool)
     * @param  lpAmount amounts for CurveFI stablecoins in pool (denormalized to token decimals)
     */
    function withdraw(uint256 lpAmount) public {
        address stableCoins = ICurveFi_DepositY(curveFi_Deposit)
            .underlying_coins();

        // Calculate amount of Curve LP-tokens to withdraw
        uint256 nWithdraw;
        nWithdraw = nWithdraw.add(normalize(stableCoins, lpAmount));

        uint256 withdrawShares = calculateShares(nWithdraw);

        // Unstake Curve LP tokens from Gauge
        ICurveFi_Gauge(curveFi_LPGauge).withdraw(withdrawShares);

        // Withdraw stablecoins from CurveDeposit
        IERC20(curveFi_LPToken).safeApprove(curveFi_Deposit, withdrawShares);
        ICurveFi_DepositY(curveFi_Deposit).remove_liquidity_imbalance(
            lpAmount,
            withdrawShares
        );

        // Send stableCoins to the requestor
        IERC20 stableCoin = IERC20(stableCoins);
        uint256 balance = stableCoin.balanceOf(address(this));
        uint256 amount = (balance <= lpAmount) ? balance : lpAmount;
        stableCoin.safeTransfer(_msgSender(), amount);
    }

    /**
     * @notice Claimes the accumulated CRV rewards from Curve
     */
    function harvest() public {
        // stake Curve LP tokens into Gauge and get CRV rewards
        uint256 curveLPBalance = IERC20(curveFi_LPToken).balanceOf(
            address(this)
        );

        IERC20(curveFi_LPToken).safeApprove(curveFi_LPGauge, curveLPBalance);
        ICurveFi_Gauge(curveFi_LPGauge).deposit(curveLPBalance);

        // get all the rewards
        crvTokenClaim();
        uint256 crvAmount = IERC20(curveFi_CRVToken).balanceOf(address(this));
        IERC20(curveFi_CRVToken).safeTransfer(_msgSender(), crvAmount);
    }

    /**
     * @notice Calculate Exchange Rate between DAI and LP Token
     */
    function exchangeRate() public view returns (uint256) {
        return exchange_rate_between_DAI_and_LPToken;
    }

    /**
     * @notice Get amount of CurveFi LP tokens staked in the Gauge
     */
    function curveLPTokenStaked() public view returns (uint256) {
        return ICurveFi_Gauge(curveFi_LPGauge).balanceOf(address(this));
    }

    /**
     * @notice Get amount of unstaked CurveFi LP tokens
     */
    function curveLPTokenUnstaked() public view returns (uint256) {
        return IERC20(curveFi_LPToken).balanceOf(address(this));
    }

    /**
     * @notice Get full amount of Curve LP tokens available for this contract
     */
    function curveLPTokenBalance() public view returns (uint256) {
        uint256 staked = curveLPTokenStaked();
        uint256 unstaked = curveLPTokenUnstaked();
        return unstaked.add(staked);
    }

    /**
     * @notice Claim CRV reward
     */
    function crvTokenClaim() internal {
        ICurveFi_Minter(curveFi_CRVMinter).mint(curveFi_LPGauge);
    }

    /**
     * @notice Calculate shared part of this contract in LP token distriution
     * @param normalizedWithdraw amount of stablecoins to withdraw normalized to 18 decimals
     */
    function calculateShares(uint256 normalizedWithdraw)
        internal
        view
        returns (uint256)
    {
        uint256 nBalance = normalizedBalance();
        uint256 poolShares = curveLPTokenBalance();

        return poolShares.mul(normalizedWithdraw).div(nBalance);
    }

    /**
     * @notice Balances of stablecoins available for withdraw
     */
    function balanceOfAll() public view returns (uint256 balances) {
        address stablecoin = ICurveFi_DepositY(curveFi_Deposit)
            .underlying_coins();

        uint256 curveLPBalance = curveLPTokenBalance();
        uint256 curveLPTokenSupply = IERC20(curveFi_LPToken).totalSupply();

        require(curveLPTokenSupply > 0, "No Curve LP tokens minted");

        //Get Y-tokens balance
        uint256 yLPTokenBalance = ICurveFi_SwapY(curveFi_Swap).balances(
            stablecoin
        );
        address yCoin = ICurveFi_SwapY(curveFi_Swap).coins(stablecoin);

        //Calculate user's shares in Y-tokens
        uint256 yShares = yLPTokenBalance.mul(curveLPBalance).div(
            curveLPTokenSupply
        );

        //Get Y-token price for underlying coin
        uint256 yPrice = IYERC20(yCoin).getPricePerFullShare();

        //Re-calculate available stablecoins balance by Y-tokens shares
        balances = yPrice.mul(yShares).div(1e18);
    }

    /**
     * @notice Balances of stablecoins available for withdraw normalized to 18 decimals
     */
    function normalizedBalance() public view returns (uint256) {
        address stablecoins = ICurveFi_DepositY(curveFi_Deposit)
            .underlying_coins();
        uint256 balances = balanceOfAll();

        uint256 sum;
        sum = sum.add(normalize(stablecoins, balances));
        return sum;
    }

    /**
     * @notice Util to normalize balance up to 18 decimals
     */
    function normalize(address coin, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint8 decimals = ERC20Detailed(coin).decimals();
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(uint256(10)**(decimals - 18));
        } else if (decimals < 18) {
            return amount.mul(uint256(10)**(18 - decimals));
        }
    }
}
