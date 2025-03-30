// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {VestingTokenManager} from "../src/VestingTokenManager.sol";
import {VestingToken} from "../src/VestingToken.sol";
import {DeployVestingTokenManager} from "../script/DeployVestingTokenManager.s.sol";
import {DeployVestingToken} from "../script/DeployVestingToken.s.sol";
import {MockToken} from "./mock/MockToken.sol";
import {MaliciousMockToken} from "./mock/MaliciousMockToken.sol";

contract VestingTokenManagerTest is Test {
    VestingTokenManager public tokenVesting;
    VestingToken public vestToken;
    DeployVestingTokenManager public deployerVesting;
    DeployVestingToken public deployerToken;

    event TokenDistribution(
        address indexed operator,
        uint256 recipientCount,
        uint256 totalAmount
    );

    address public ADMIN = makeAddr("admin");
    address public OWNER_VESTING_MANAGER = makeAddr("ownerVestingManager");
    // address public OWNER = makeAddr("owner");
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");
    address public USER_Vesting = makeAddr("userVesting");
    address public USER = makeAddr("user");
    address public Granter = makeAddr("granter");

    uint256 public constant STARTING_BALANCE = 10000000 ether;
    uint256 public constant SOME_BALANCE = 1000;
    uint256 public constant VESTING_AMOUNT = 100;
    uint256 public constant VESTING_START = 300000000;
    uint256 public constant VESTING_DURATION = 365 days;
    uint256 public constant VESTING_UNIT = 20;
    bool public constant VESTING_REVOCABLE = true;

    uint256 constant BOB_STARTING_AMOUNT = 100 ether;
    uint256 constant ALICE_STARTING_AMOUNT = 100 ether;

    MockToken mockToken;

    function setUp() public {
        // Deploy VestingToken using the deployment script
        deployerToken = new DeployVestingToken();
        deployerToken.setAddresses(ADMIN, OWNER_VESTING_MANAGER);
        vestToken = deployerToken.run();

        // Deploy VestingTokenManager
        deployerVesting = new DeployVestingTokenManager();
        deployerVesting.setAddresses(OWNER_VESTING_MANAGER, address(vestToken));
        tokenVesting = deployerVesting.run();

        // Grant VESTING_MANAGER_ROLE to tokenVestingManager contract
        vm.startPrank(ADMIN);
        vestToken.grantRole(
            vestToken.VESTING_MANAGER_ROLE(),
            address(tokenVesting)
        );

        // Give some ETH to test addresses
        vm.deal(ALICE, SOME_BALANCE);
        vm.deal(BOB, SOME_BALANCE);
        vm.deal(USER, SOME_BALANCE);
        vm.deal(OWNER_VESTING_MANAGER, SOME_BALANCE);

        deal(address(vestToken), USER, 500000);
    }

    ////////////////////////////////////###################
    ////////////////////////////////////###################createFixedVestingSchedules

    function testCreateFixedVestingSchedulesFailedLengthOfAddressesIsZero()
        public
    {
        address[] memory granters;
        // addresses[0] = payable(address(0)); // Cast to address payable
        vm.expectRevert(); // hey, the next line should revet/fail
        tokenVesting.createFixedVestingSchedules(
            granters,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            VESTING_REVOCABLE
        );
    }

    function testCreateFixedVestingSchedulesFailedLengthOfAddressesIsMoreThan100()
        public
    {
        address[] memory granters = new address[](101); // addresses[0] = payable(address(0)); // Cast to address payable

        vm.expectRevert(); // hey, the next line should revet/fail
        tokenVesting.createFixedVestingSchedules(
            granters,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            VESTING_REVOCABLE
        );
    }

    function testCreateFixedVestingSchedulesFailedWithInsufficientAllowance()
        public
    {
        address[] memory granters = new address[](10);
        for (uint i = 0; i < 10; i++) {
            granters[i] = address(uint160(i + 1));
        }

        uint256 totalAmount = VESTING_AMOUNT * granters.length;
        uint256 insufficientAllowance = totalAmount - 1; // One less than required

        vm.startPrank(OWNER_VESTING_MANAGER);
        // Approve less than required
        vestToken.approve(address(tokenVesting), insufficientAllowance);

        // This should revert due to insufficient allowance
        vm.expectRevert();
        tokenVesting.createFixedVestingSchedules(
            granters,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            VESTING_REVOCABLE
        );
        vm.stopPrank();
    }

    function testCreateFixedVestingSchedulesFailedWhenCallerIsNotOwner()
        public
    {
        address[] memory granters = new address[](10);
        for (uint i = 0; i < 10; i++) {
            granters[i] = address(uint160(i + 1));
        }

        uint256 requiredAmount = VESTING_AMOUNT * granters.length;
        console.log(vestToken.balanceOf(USER));

        vm.startPrank(USER);
        // Approve more than enough
        vestToken.approve(address(tokenVesting), requiredAmount * 2);

        // This should revert due to insufficient balance
        vm.startPrank(USER);
        vm.expectRevert();
        tokenVesting.createFixedVestingSchedules(
            granters,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            VESTING_REVOCABLE
        );
        vm.stopPrank();
    }

    function testCreateFixedVestingSchedulesSuccessWithSufficientTokenAllowance()
        public
    {
        address[] memory granters = new address[](10);
        for (uint i = 0; i < 10; i++) {
            granters[i] = address(uint160(i + 1));
        }

        uint256 requiredAmount = VESTING_AMOUNT * granters.length;

        vm.startPrank(OWNER_VESTING_MANAGER);
        // Approve more than enough
        vestToken.approve(address(tokenVesting), requiredAmount * 2);

        console.log(
            vestToken.allowance(OWNER_VESTING_MANAGER, address(tokenVesting))
        );
        uint256 startingSenderBalance = vestToken.balanceOf(
            OWNER_VESTING_MANAGER
        );
        uint256 startingRecipientBalance = vestToken.balanceOf(granters[0]);

        // Act
        vm.startPrank(OWNER_VESTING_MANAGER);
        tokenVesting.createFixedVestingSchedules(
            granters,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            VESTING_REVOCABLE
        );
        vm.stopPrank();

        uint256 endingRecipientBalance = vestToken.balanceOf(granters[0]);
        uint256 endingSenderBalance = vestToken.balanceOf(
            OWNER_VESTING_MANAGER
        );

        assertEq(
            endingRecipientBalance,
            startingRecipientBalance + VESTING_AMOUNT
        );

        assertEq(endingSenderBalance, startingSenderBalance - requiredAmount);
    }

    // Test for transferable tokens after creating vesting schedules:
    function testTransferableTokensAfterVesting() public {
        address[] memory granters = new address[](2);
        granters[0] = ALICE;
        granters[1] = BOB;

        uint256 initialBalance = vestToken.balanceOf(ALICE);

        vm.startPrank(OWNER_VESTING_MANAGER);
        vestToken.approve(
            address(tokenVesting),
            VESTING_AMOUNT * granters.length
        );

        tokenVesting.createFixedVestingSchedules(
            granters,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            VESTING_REVOCABLE
        );
        vm.stopPrank();

        uint256 transferableTokens = vestToken.transferableTokens(ALICE);
        assertEq(
            transferableTokens,
            initialBalance,
            "All new tokens should be locked initially"
        );

        // Move time forward to halfway through vesting period
        vm.warp(VESTING_START + VESTING_DURATION / 2);

        transferableTokens = vestToken.transferableTokens(ALICE);
        assertEq(
            transferableTokens,
            initialBalance,
            "All new tokens should still be locked"
        );

        // Move time to just after the vesting period ends
        vm.warp(VESTING_START + VESTING_DURATION + 1);

        transferableTokens = vestToken.transferableTokens(ALICE);
        assertEq(
            transferableTokens,
            5,
            "Some tokens should now be transferable"
        );
    }

    ////////////////////////////////////###################
    ////////////////////////////////////###################createFlexibleVestingSchedules
    // Attempt to create with an empty array
    function testCreateFlexibleVestingSchedulesEmptyArray() public {
        VestingTokenManager.VestingParams[]
            memory params = new VestingTokenManager.VestingParams[](0);

        vm.startPrank(OWNER_VESTING_MANAGER);
        vm.expectRevert("Invalid array");
        tokenVesting.createFlexibleVestingSchedules(params);
        vm.stopPrank();
    }

    // Attempt to create with too many recipients
    function testCreateFlexibleVestingSchedulesTooManyRecipients() public {
        VestingTokenManager.VestingParams[]
            memory params = new VestingTokenManager.VestingParams[](101);
        for (uint i = 0; i < 101; i++) {
            params[i] = VestingTokenManager.VestingParams(
                address(uint160(i + 1)),
                VESTING_AMOUNT,
                VESTING_START,
                VESTING_DURATION,
                VESTING_UNIT,
                true
            );
        }

        vm.startPrank(OWNER_VESTING_MANAGER);
        vm.expectRevert("Too many recipients");
        tokenVesting.createFlexibleVestingSchedules(params);
        vm.stopPrank();
    }

    // Insufficient token balance
    function testCreateFlexibleVestingSchedulesInsufficientBalance() public {
        VestingTokenManager.VestingParams[]
            memory params = new VestingTokenManager.VestingParams[](2);
        params[0] = VestingTokenManager.VestingParams(
            ALICE,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );
        params[1] = VestingTokenManager.VestingParams(
            BOB,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );

        uint256 totalAmount = VESTING_AMOUNT * 2;

        vm.startPrank(OWNER_VESTING_MANAGER);
        vestToken.approve(address(tokenVesting), totalAmount);

        // Set balance to be less than required
        uint256 currentBalance = vestToken.balanceOf(OWNER_VESTING_MANAGER);
        vestToken.transfer(address(0x1), currentBalance - totalAmount + 1);

        vm.expectRevert(
            abi.encodeWithSignature(
                "InsufficientValue(string)",
                "Insufficient token balance"
            )
        );
        tokenVesting.createFlexibleVestingSchedules(params);
        vm.stopPrank();
    }

    // Attempt to create by a non-owner
    function testCreateFlexibleVestingSchedulesNotOwner() public {
        VestingTokenManager.VestingParams[]
            memory params = new VestingTokenManager.VestingParams[](2);
        params[0] = VestingTokenManager.VestingParams(
            ALICE,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );
        params[1] = VestingTokenManager.VestingParams(
            BOB,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );

        vm.expectRevert();
        vm.startPrank(ALICE);
        tokenVesting.createFlexibleVestingSchedules(params);
        vm.stopPrank();
    }

    // Attempt to create when the contract is paused
    function testCreateFlexibleVestingSchedulesWhenPaused() public {
        VestingTokenManager.VestingParams[]
            memory params = new VestingTokenManager.VestingParams[](2);
        params[0] = VestingTokenManager.VestingParams(
            ALICE,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );
        params[1] = VestingTokenManager.VestingParams(
            BOB,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );

        vm.startPrank(OWNER_VESTING_MANAGER);
        tokenVesting.pause();

        vm.expectRevert();
        tokenVesting.createFlexibleVestingSchedules(params);
        vm.stopPrank();
    }

    // Creation with different parameters for each vesting schedule
    function testCreateFlexibleVestingSchedulesDifferentParameters() public {
        VestingTokenManager.VestingParams[]
            memory params = new VestingTokenManager.VestingParams[](3);
        params[0] = VestingTokenManager.VestingParams(
            ALICE,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );
        params[1] = VestingTokenManager.VestingParams(
            BOB,
            VESTING_AMOUNT * 2,
            VESTING_START + 1 days,
            VESTING_DURATION * 2,
            VESTING_UNIT * 2,
            false
        );
        params[2] = VestingTokenManager.VestingParams(
            USER,
            VESTING_AMOUNT / 2,
            VESTING_START + 2 days,
            VESTING_DURATION / 2,
            VESTING_UNIT / 2,
            true
        );

        uint256 totalAmount = VESTING_AMOUNT *
            2 +
            VESTING_AMOUNT +
            VESTING_AMOUNT /
            2;

        vm.startPrank(OWNER_VESTING_MANAGER);
        vestToken.approve(address(tokenVesting), totalAmount);

        tokenVesting.createFlexibleVestingSchedules(params);

        vm.stopPrank();

        // Check vesting schedules were created with correct parameters
        VestingToken.GrantInfo[] memory aliceGrants = vestToken.getGrants(
            ALICE
        );
        VestingToken.GrantInfo[] memory bobGrants = vestToken.getGrants(BOB);
        VestingToken.GrantInfo[] memory userGrants = vestToken.getGrants(USER);

        assertEq(aliceGrants.length, 1, "ALICE should have 1 vesting schedule");
        assertEq(bobGrants.length, 1, "BOB should have 1 vesting schedule");
        assertEq(userGrants.length, 1, "USER should have 1 vesting schedule");

        assertEq(
            aliceGrants[0].schedule.amount,
            VESTING_AMOUNT,
            "ALICE's vesting amount should match"
        );
        assertEq(
            bobGrants[0].schedule.amount,
            VESTING_AMOUNT * 2,
            "BOB's vesting amount should match"
        );
        assertEq(
            userGrants[0].schedule.amount,
            VESTING_AMOUNT / 2,
            "USER's vesting amount should match"
        );

        assertEq(
            bobGrants[0].schedule.start,
            VESTING_START + 1 days,
            "BOB's vesting start should match"
        );
        assertEq(
            bobGrants[0].schedule.duration,
            VESTING_DURATION * 2,
            "BOB's vesting duration should match"
        );
        assertEq(
            bobGrants[0].schedule.unit,
            VESTING_UNIT * 2,
            "BOB's vesting unit should match"
        );
        assertEq(
            bobGrants[0].schedule.revocable,
            false,
            "BOB's vesting should not be revocable"
        );

        assertEq(
            userGrants[0].schedule.start,
            VESTING_START + 2 days,
            "USER's vesting start should match"
        );
        assertEq(
            userGrants[0].schedule.duration,
            VESTING_DURATION / 2,
            "USER's vesting duration should match"
        );
        assertEq(
            userGrants[0].schedule.unit,
            VESTING_UNIT / 2,
            "USER's vesting unit should match"
        );
    }

    // Successful creation of flexible vesting schedules
    function testCreateFlexibleVestingSchedulesSuccess() public {
        VestingTokenManager.VestingParams[]
            memory params = new VestingTokenManager.VestingParams[](2);
        params[0] = VestingTokenManager.VestingParams(
            ALICE,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );
        params[1] = VestingTokenManager.VestingParams(
            BOB,
            VESTING_AMOUNT * 2,
            VESTING_START + 1 days,
            VESTING_DURATION * 2,
            VESTING_UNIT * 2,
            false
        );

        uint256 totalAmount = VESTING_AMOUNT * 3;

        vm.startPrank(OWNER_VESTING_MANAGER);
        vestToken.approve(address(tokenVesting), totalAmount);

        vm.expectEmit(true, true, true, true);
        emit TokenDistribution(OWNER_VESTING_MANAGER, 2, totalAmount);

        tokenVesting.createFlexibleVestingSchedules(params);

        vm.stopPrank();

        // Check vesting schedules were created
        VestingToken.GrantInfo[] memory aliceGrants = vestToken.getGrants(
            ALICE
        );
        VestingToken.GrantInfo[] memory bobGrants = vestToken.getGrants(BOB);

        assertEq(aliceGrants.length, 1, "ALICE should have 1 vesting schedule");
        assertEq(bobGrants.length, 1, "BOB should have 1 vesting schedule");
        assertEq(
            aliceGrants[0].schedule.amount,
            VESTING_AMOUNT,
            "ALICE's vesting amount should match"
        );
        assertEq(
            bobGrants[0].schedule.amount,
            VESTING_AMOUNT * 2,
            "BOB's vesting amount should match"
        );
    }

    // checks transferable tokens and balances
    function testTransferableTokensAfterFlexibleVesting() public {
        VestingTokenManager.VestingParams[]
            memory params = new VestingTokenManager.VestingParams[](2);
        params[0] = VestingTokenManager.VestingParams(
            ALICE,
            VESTING_AMOUNT,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );
        params[1] = VestingTokenManager.VestingParams(
            BOB,
            VESTING_AMOUNT * 2,
            VESTING_START,
            VESTING_DURATION,
            VESTING_UNIT,
            true
        );

        uint256 initialBalanceAlice = vestToken.balanceOf(ALICE);
        uint256 initialBalanceBob = vestToken.balanceOf(BOB);

        console.log("Initial balance ALICE:", initialBalanceAlice);
        console.log("Initial balance BOB:", initialBalanceBob);

        vm.startPrank(OWNER_VESTING_MANAGER);
        vestToken.approve(address(tokenVesting), VESTING_AMOUNT * 3);

        tokenVesting.createFlexibleVestingSchedules(params);
        vm.stopPrank();

        console.log(
            "Balance ALICE after vesting creation:",
            vestToken.balanceOf(ALICE)
        );
        console.log(
            "Balance BOB after vesting creation:",
            vestToken.balanceOf(BOB)
        );

        uint256 transferableTokensAlice = vestToken.transferableTokens(ALICE);
        uint256 transferableTokensBob = vestToken.transferableTokens(BOB);

        console.log(
            "Transferable tokens ALICE initially:",
            transferableTokensAlice
        );
        console.log(
            "Transferable tokens BOB initially:",
            transferableTokensBob
        );

        assertEq(
            transferableTokensAlice,
            initialBalanceAlice,
            "All new tokens for ALICE should be locked initially"
        );
        assertEq(
            transferableTokensBob,
            initialBalanceBob,
            "All new tokens for BOB should be locked initially"
        );

        // Move time forward to halfway through vesting period
        vm.warp(VESTING_START + VESTING_DURATION / 2);

        transferableTokensAlice = vestToken.transferableTokens(ALICE);
        transferableTokensBob = vestToken.transferableTokens(BOB);

        console.log(
            "Transferable tokens ALICE at halfway:",
            transferableTokensAlice
        );
        console.log(
            "Transferable tokens BOB at halfway:",
            transferableTokensBob
        );

        assertEq(
            transferableTokensAlice,
            initialBalanceAlice,
            "All new tokens for ALICE should still be locked"
        );
        assertEq(
            transferableTokensBob,
            initialBalanceBob,
            "All new tokens for BOB should still be locked"
        );

        // Move time to just after the vesting period ends
        vm.warp(VESTING_START + VESTING_DURATION + 1);

        transferableTokensAlice = vestToken.transferableTokens(ALICE);
        transferableTokensBob = vestToken.transferableTokens(BOB);

        console.log(
            "Transferable tokens ALICE after vesting:",
            transferableTokensAlice
        );
        console.log(
            "Transferable tokens BOB after vesting:",
            transferableTokensBob
        );

        uint256 expectedTransferableAlice = initialBalanceAlice +
            ((VESTING_AMOUNT * 5) / 100); // 5% of VESTING_AMOUNT
        uint256 expectedTransferableBob = initialBalanceBob +
            ((VESTING_AMOUNT * 2 * 5) / 100); // 5% of VESTING_AMOUNT * 2

        assertEq(
            transferableTokensAlice,
            expectedTransferableAlice,
            "5% of tokens should now be transferable for ALICE"
        );
        assertEq(
            transferableTokensBob,
            expectedTransferableBob,
            "5% of tokens should now be transferable for BOB"
        );

        // Check final balances
        console.log("Final balance ALICE:", vestToken.balanceOf(ALICE));
        console.log("Final balance BOB:", vestToken.balanceOf(BOB));
    }

    // .... to be continued
}
