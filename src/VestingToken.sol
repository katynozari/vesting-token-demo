// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract VestingToken is ERC20, AccessControl {
    error CannotTransfer(string message);
    error NotRevocableGrant(string message);

    struct VestingSchedule {
        address granter;
        uint256 amount;
        uint256 start;
        uint256 duration;
        uint256 unit;
        bool revocable;
    }

    struct GrantInfo {
        VestingSchedule schedule;
        uint256 releaseTokens;
    }

    uint256 private constant _TOTAL_SUPPLY = 10000000 * (10 ** 18);
    mapping(address => VestingSchedule[]) public grants;
    bytes32 public constant VESTING_MANAGER_ROLE =
        keccak256("VESTING_MANAGER_ROLE");

    event VestingScheduleCreated(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 start,
        uint256 duration,
        uint256 unit,
        bool revocable
    );
    event VestingScheduleRevoked(address indexed holder, uint256 grantId);
    event TokensVested(address indexed holder, uint256 amount);

    constructor(
        address _admin,
        address _vestingManager
    ) ERC20("VESTING TOKEN", "VEST") {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VESTING_MANAGER_ROLE, _vestingManager);
        _mint(_vestingManager, _TOTAL_SUPPLY);
    }

    /*
     * @dev This function can only be called by accounts with the VESTING_MANAGER_ROLE.
     * @notice Creates a new vesting schedule
     * @param granter Address of the granter
     * @param amount Amount of tokens to vest
     * @param start Start time of vesting
     * @param duration Duration of vesting
     * @param unit Number of vesting periods
     * @param revocable Whether the grant is revocable
     */
    function createVestingSchedule(
        address granter,
        uint256 amount,
        uint256 start,
        uint256 duration,
        uint256 unit,
        bool revocable
    ) external onlyRole(VESTING_MANAGER_ROLE) {
        require(granter != address(0), "Granter address is zero address!");
        require(amount > 0, "Amount must be greater than zero!");
        require(
            unit > 0 && unit <= 100,
            "unit should be greater than zero and smaller than 100!"
        );
        require(
            grants[granter].length < 10,
            "Cannot vest more than 10 times for a granter!"
        );
        uint256 currentTime = block.timestamp;
        if (start == 0 || start < currentTime) {
            start = currentTime;
        }

        if (duration > 0) {
            grants[granter].push(
                VestingSchedule({
                    granter: granter,
                    amount: amount,
                    start: start,
                    duration: duration,
                    unit: unit,
                    revocable: revocable
                })
            );
        }
        super.transfer(granter, amount);

        emit VestingScheduleCreated(
            msg.sender,
            granter,
            amount,
            start,
            duration,
            unit,
            revocable
        );
    }

    /*
    @notice Returns the amount of transferable tokens for a holder
    @param holder Address of the token holder
    @return Amount of transferable tokens
    */
    function transferableTokens(
        address holder
    ) external view returns (uint256) {
        return _transferableTokens(holder, block.timestamp);
    }

    /**
     * @dev This function can only be called by accounts with the VESTING_MANAGER_ROLE.
     * @notice Revokes a vesting schedule
     * @param granter Address of the granter
     * @param grantIndex Index of the grant to revoke
     */
    function revokeVestingSchedule(
        address granter,
        uint256 grantIndex
    ) external onlyRole(VESTING_MANAGER_ROLE) {
        uint256 grantsLength = grants[granter].length;
        require(grantIndex < grantsLength, "Invalid grant Index!");
        require(grantsLength > 0, "Holder has no grants!");
        VestingSchedule storage grant = grants[granter][grantIndex];
        if (
            !grant.revocable &&
            block.timestamp < grant.start + (2 * grant.duration)
        ) {
            revert NotRevocableGrant("Grant is not revocable");
        }
        grants[granter][grantIndex] = grants[granter][grantsLength - 1];
        grants[granter].pop();

        emit VestingScheduleRevoked(granter, grantIndex);
    }

    /**
     * @notice Retrieves all grant information for a specific address
     * @param granter The address of the grant holder
     * @return An array of GrantInfo structs containing vesting schedules and releasable tokens
     */
    function getGrants(
        address granter
    ) external view returns (GrantInfo[] memory) {
        uint256 grantsLength = grants[granter].length;
        require(grantsLength > 0, "Holder has no grants");

        GrantInfo[] memory grantInfos = new GrantInfo[](grantsLength);

        uint256 currentTime = block.timestamp;
        for (uint256 i = 0; i < grantsLength; ++i) {
            VestingSchedule memory schedule = grants[granter][i];
            uint256 releaseTokens = schedule.amount -
                _vestedTokens(schedule, currentTime);

            grantInfos[i] = GrantInfo({
                schedule: schedule,
                releaseTokens: releaseTokens
            });
        }
        return grantInfos;
    }

    /**
     * @notice Overrides ERC20 transfer function to check for transferable tokens
     * @param to Recipient of the transfer
     * @param amount Amount to transfer
     * @return bool indicating success of the transfer
     */
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (amount > _transferableTokens(msg.sender, block.timestamp)) {
            revert CannotTransfer(
                "Cannot Transfer: your amount is greater than transfableTokens."
            );
        }
        super.transfer(to, amount);
        return true;
    }

    /**
     * @notice Overrides ERC20 transferFrom function to check for transferable tokens
     * @param from Sender of the transfer
     * @param to Recipient of the transfer
     * @param amount Amount to transfer
     * @return bool indicating success of the transfer
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (amount > _transferableTokens(from, block.timestamp)) {
            revert CannotTransfer(
                "Cannot Transfer: your amount is greater than transfableTokens."
            );
        }
        super.transferFrom(from, to, amount);
        return true;
    }

    /**
     * @notice Calculates the amount of transferable tokens for a holder
     * @param holder Address of the token holder
     * @param time Current time
     * @return Amount of transferable tokens
     */
    function _transferableTokens(
        address holder,
        uint256 time
    ) internal view returns (uint256) {
        uint256 grantCount = grants[holder].length;
        if (grantCount == 0) return balanceOf(holder);

        uint256 totalVested = 0;
        for (uint256 i = 0; i < grantCount; ++i) {
            totalVested += _vestedTokens(grants[holder][i], time);
        }
        return balanceOf(holder) - totalVested;
    }

    /**
     * @notice Calculates the amount of vested tokens for a grant
     * @param grant VestingSchedule to calculate vested tokens for
     * @param time Current time
     * @return Amount of vested tokens
     */
    function _vestedTokens(
        VestingSchedule memory grant,
        uint256 time
    ) internal pure returns (uint256) {
        if (time < grant.start + grant.duration) {
            return grant.amount;
        }
        uint256 timeAfterVesting = time - (grant.start + grant.duration);
        uint256 periodDuration = grant.duration / grant.unit;
        if (grant.duration < grant.unit) {
            periodDuration = 1;
        }
        uint256 elapsedPeriods = (timeAfterVesting / periodDuration) + 1;

        if (elapsedPeriods >= grant.unit) {
            return 0;
        }
        return grant.amount - ((grant.amount * elapsedPeriods) / grant.unit);
    }
}
