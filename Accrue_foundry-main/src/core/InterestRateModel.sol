// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";

/// @title InterestRateModel
/// @notice Linear interest rate model based on utilization rate
/// @dev Based on Aave's interest rate model
contract InterestRateModel is IInterestRateModel, Ownable {
    using WadRayMath for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Seconds per year for rate calculations
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    /// @notice 100% in WAD (18 decimals)
    uint256 public constant WAD = 1e18;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Base rate (rate at 0% utilization) - annual rate in WAD
    uint256 public baseRate;

    /// @notice Slope 1 - rate increase below optimal utilization
    uint256 public slope1;

    /// @notice Slope 2 - rate increase above optimal utilization
    uint256 public slope2;

    /// @notice Optimal utilization rate (e.g., 0.8e18 = 80%)
    uint256 public optimalUtilization;

    /// @notice Reserve factor - percentage of interest that goes to reserves
    uint256 public reserveFactor;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RateParametersUpdated(uint256 baseRate, uint256 slope1, uint256 slope2, uint256 optimalUtilization);
    event ReserveFactorUpdated(uint256 reserveFactor);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the interest rate model with default parameters
    /// @param _owner The owner address
    constructor(address _owner) Ownable(_owner) {
        // Default parameters (similar to Aave stablecoins)
        baseRate = 0.02e18; // 2% base rate
        slope1 = 0.04e18; // 4% slope below optimal
        slope2 = 0.75e18; // 75% slope above optimal
        optimalUtilization = 0.8e18; // 80% optimal utilization
        reserveFactor = 0.1e18; // 10% reserve factor
    }

    /*//////////////////////////////////////////////////////////////
                            RATE CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IInterestRateModel
    function getBorrowRate(uint256 utilizationRate) public view returns (uint256) {
        if (utilizationRate == 0) {
            return baseRate / SECONDS_PER_YEAR;
        }

        uint256 annualRate;

        if (utilizationRate <= optimalUtilization) {
            // Below optimal: baseRate + (utilization / optimal) * slope1
            uint256 utilizationRatio = utilizationRate.wadDiv(optimalUtilization);
            annualRate = baseRate + utilizationRatio.wadMul(slope1);
        } else {
            // Above optimal: baseRate + slope1 + ((utilization - optimal) / (1 - optimal)) * slope2
            uint256 excessUtilization = utilizationRate - optimalUtilization;
            uint256 maxExcess = WAD - optimalUtilization;
            uint256 excessRatio = excessUtilization.wadDiv(maxExcess);
            annualRate = baseRate + slope1 + excessRatio.wadMul(slope2);
        }

        // Convert annual rate to per-second rate
        return annualRate / SECONDS_PER_YEAR;
    }

    /// @inheritdoc IInterestRateModel
    function getDepositRate(uint256 utilizationRate) public view returns (uint256) {
        uint256 borrowRate = getBorrowRate(utilizationRate);

        // depositRate = borrowRate * utilizationRate * (1 - reserveFactor)
        uint256 grossRate = borrowRate.wadMul(utilizationRate);
        return grossRate.wadMul(WAD - reserveFactor);
    }

    /// @inheritdoc IInterestRateModel
    function getRates(uint256 utilizationRate) external view returns (uint256 borrowRate, uint256 depositRate) {
        borrowRate = getBorrowRate(utilizationRate);
        depositRate = getDepositRate(utilizationRate);
    }

    /*//////////////////////////////////////////////////////////////
                              ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update interest rate parameters
    /// @param _baseRate New base rate (annual, 18 decimals)
    /// @param _slope1 New slope 1
    /// @param _slope2 New slope 2
    /// @param _optimalUtilization New optimal utilization
    function setRateParameters(uint256 _baseRate, uint256 _slope1, uint256 _slope2, uint256 _optimalUtilization)
        external
        onlyOwner
    {
        require(_optimalUtilization <= WAD, "Invalid optimal utilization");

        baseRate = _baseRate;
        slope1 = _slope1;
        slope2 = _slope2;
        optimalUtilization = _optimalUtilization;

        emit RateParametersUpdated(_baseRate, _slope1, _slope2, _optimalUtilization);
    }

    /// @notice Update reserve factor
    /// @param _reserveFactor New reserve factor (18 decimals)
    function setReserveFactor(uint256 _reserveFactor) external onlyOwner {
        require(_reserveFactor <= WAD, "Invalid reserve factor");
        reserveFactor = _reserveFactor;
        emit ReserveFactorUpdated(_reserveFactor);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get annual rates for display purposes
    /// @param utilizationRate The utilization rate
    /// @return annualBorrowRate Annual borrow rate (18 decimals)
    /// @return annualDepositRate Annual deposit rate (18 decimals)
    function getAnnualRates(uint256 utilizationRate)
        external
        view
        returns (uint256 annualBorrowRate, uint256 annualDepositRate)
    {
        annualBorrowRate = getBorrowRate(utilizationRate) * SECONDS_PER_YEAR;
        annualDepositRate = getDepositRate(utilizationRate) * SECONDS_PER_YEAR;
    }
}
