// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./VestingToken.sol";

/** 
@title VestingTokenManager
@notice Manages vesting schedules and airdrops for VestingToken
@dev Implements vesting and airdrop functionalities with both fixed and flexible 
*/
contract VestingTokenManager is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for VestingToken;
    using SafeERC20 for IERC20;
    error InsufficientTokenAllowance(string message);
    error InsufficientValue(string message);

    struct VestingParams {
        address granter;
        uint256 amount;
        uint256 start;
        uint256 duration;
        uint256 unit;
        bool revocable;
    }
    event TokenDistribution(
        address indexed operator,
        uint256 recipientCount,
        uint256 totalAmount
    );
    event TokenWithdrawn(address indexed tokenAddress, address indexed owner);

    VestingToken public vestToken;

    /**
     * @notice Initializes the contract with the owner and token address
     * @param _initialOwner Address of the initial owner
     * @param _vestToken Address of the VestingToken contract
     */
    constructor(
        address _initialOwner,
        address _vestToken
    ) Ownable(_initialOwner) {
        vestToken = VestingToken(_vestToken);
    }

    /**
     * @notice Creates multiple vesting schedules with fixed parameters
     * @param granters Array of addresses to receive vesting schedules
     * @param amount Amount of tokens for each schedule
     * @param start Start time of the vesting
     * @param duration Duration of the vesting period
     * @param unit Number of vesting units
     * @param revocable Whether the vesting is revocable
     */
    function createFixedVestingSchedules(
        address[] calldata granters,
        uint256 amount,
        uint256 start,
        uint256 duration,
        uint256 unit,
        bool revocable
    ) external onlyOwner whenNotPaused nonReentrant {
        uint256 grantersLength = granters.length;
        require(grantersLength > 0, "Invalid array");
        require(grantersLength <= 100, "Too many recipients");

        uint256 totalAmount = amount * granters.length;
        if (vestToken.allowance(msg.sender, address(this)) < totalAmount) {
            revert InsufficientTokenAllowance("Insufficient allowance");
        }
        uint256 balance = vestToken.balanceOf(msg.sender);
        if (balance < totalAmount) {
            revert InsufficientValue("Insufficient token balance");
        }
        // Transfer tokens to this contract
        vestToken.safeTransferFrom(msg.sender, address(this), totalAmount);

        for (uint i = 0; i < granters.length; ++i) {
            vestToken.createVestingSchedule(
                granters[i],
                amount,
                start,
                duration,
                unit,
                revocable
            );
        }
        emit TokenDistribution(msg.sender, grantersLength, totalAmount);
    }

    /**
     * @notice Creates multiple vesting schedules with flexible parameters
     * @param params Array of VestingParams structs
     */
    function createFlexibleVestingSchedules(
        VestingParams[] calldata params
    ) external onlyOwner whenNotPaused nonReentrant {
        uint256 paramsLength = params.length;
        require(paramsLength > 0, "Invalid array");
        require(paramsLength <= 100, "Too many recipients");

        uint256 totalAmount = 0;
        for (uint i = 0; i < paramsLength; ++i) {
            totalAmount += params[i].amount;
        }

        if (vestToken.allowance(msg.sender, address(this)) < totalAmount) {
            revert InsufficientTokenAllowance("Insufficient allowance");
        }
        uint256 balance = vestToken.balanceOf(msg.sender);
        if (balance < totalAmount) {
            revert InsufficientValue("Insufficient token balance");
        }

        vestToken.safeTransferFrom(msg.sender, address(this), totalAmount);

        for (uint i = 0; i < paramsLength; ++i) {
            vestToken.createVestingSchedule(
                params[i].granter,
                params[i].amount,
                params[i].start,
                params[i].duration,
                params[i].unit,
                params[i].revocable
            );
        }
        emit TokenDistribution(msg.sender, paramsLength, totalAmount);
    }

    /**
     * @notice Distributes airdrop with fixed amount per recipient
     * @param recipients Array of recipient addresses
     * @param amount Amount of tokens for each recipient
     */
    function distributeFixedAirdrop(
        address[] calldata recipients,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        uint256 recipientsLength = recipients.length;
        require(recipientsLength > 0, "No recipients provided");
        require(recipientsLength <= 100, "Too many recipients");

        uint256 totalAmount = amount * recipientsLength;
        if (vestToken.allowance(msg.sender, address(this)) < totalAmount) {
            revert InsufficientTokenAllowance(
                "Transfer amount exceeds allowance"
            );
        }

        uint256 balance = vestToken.balanceOf(msg.sender);
        if (balance < totalAmount) {
            revert InsufficientValue("Insufficient token balance");
        }

        for (uint256 i = 0; i < recipientsLength; ++i) {
            vestToken.safeTransferFrom(msg.sender, recipients[i], amount);
        }

        emit TokenDistribution(msg.sender, recipientsLength, totalAmount);
    }

    /**
     * @notice Distributes airdrop with flexible amounts per recipient
     * @param recipients Array of recipient addresses
     * @param amounts Array of token amounts corresponding to each recipient
     */
    function distributeFlexibleAirdrop(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner whenNotPaused nonReentrant {
        uint256 recipientsLength = recipients.length;
        uint256 amountsLength = recipients.length;

        require(recipientsLength > 0, "No recipients provided");
        require(recipientsLength <= 100, "Too many recipients");
        require(recipientsLength == amountsLength, "Array lengths must match");

        uint256 totalAmount = 0;
        for (uint i = 0; i < amountsLength; ++i) {
            totalAmount += amounts[i];
        }

        if (vestToken.allowance(msg.sender, address(this)) < totalAmount) {
            revert InsufficientTokenAllowance(
                "Transfer amount exceeds allowance"
            );
        }

        uint256 balance = vestToken.balanceOf(msg.sender);
        if (balance < totalAmount) {
            revert InsufficientValue("Insufficient token balance");
        }

        for (uint256 i = 0; i < recipientsLength; ++i) {
            vestToken.safeTransferFrom(msg.sender, recipients[i], amounts[i]);
        }

        emit TokenDistribution(msg.sender, recipientsLength, totalAmount);
    }

    /** @notice Withdraws all tokens from the contract to the owner */
    function withdrawToken(
        address tokenAddress
    ) external onlyOwner whenNotPaused nonReentrant {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        token.safeTransfer(owner(), balance);

        emit TokenWithdrawn(tokenAddress, owner());
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
