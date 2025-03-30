// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Test, console} from "forge-std/Test.sol";
import {VestingToken} from "../src/VestingToken.sol";
import {DeployVestingToken} from "../script/DeployVestingToken.s.sol";

contract VestingTokenTest is Test {
    VestingToken public vestToken;
    DeployVestingToken public deployer;
    address public ADMIN = makeAddr("admin");
    address public VESTING_MANAGER = makeAddr("vestingManager");
    address public ALICE = makeAddr("alice");
    address public BOB = makeAddr("bob");
    address public USER = makeAddr("user");
    address public Granter = makeAddr("granter");
    uint256 public value = 1000;
    uint256 public start = 1000;
    uint256 public duration = 300;

    uint256 constant STARTING_BALANCE = 100 ether;
    uint256 constant BOB_STARTING_AMOUNT = 100 ether;
    uint256 constant ALICE_STARTING_AMOUNT = 100 ether;

    function setUp() external {
        deployer = new DeployVestingToken();
        deployer.setAddresses(ADMIN, VESTING_MANAGER);
        vestToken = new VestingToken(ADMIN, VESTING_MANAGER);
        vm.deal(ALICE, STARTING_BALANCE);
        deal(address(vestToken), ALICE, 20000);
    }

    // test constructor
    function testConstructor() public view {
        // Test name
        assertEq(vestToken.name(), "VESTING TOKEN");

        // Test symbol
        assertEq(vestToken.symbol(), "VEST");

        // Test admin role
        assertTrue(vestToken.hasRole(vestToken.DEFAULT_ADMIN_ROLE(), ADMIN));

        // Test vesting manager role
        assertTrue(
            vestToken.hasRole(vestToken.VESTING_MANAGER_ROLE(), VESTING_MANAGER)
        );

        // Test total supply
        assertEq(vestToken.totalSupply(), 10000000 * (10 ** 18));

        // Test initial balance of vesting manager
        assertEq(vestToken.balanceOf(VESTING_MANAGER), 10000000 * (10 ** 18));
    }

    ////////////////////////// Vesting Schedule ////////////

    function testCreateVestingScheduleIsSuccessful() public {
        uint256 startingGranterBalance = vestToken.balanceOf(Granter);
        uint256 startingOwnerBalance = vestToken.balanceOf(VESTING_MANAGER);

        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start,
            duration,
            20,
            true
        );
        vm.stopPrank();
        uint256 endingGranterBalance = vestToken.balanceOf(Granter);
        uint256 endingOwnerBalance = vestToken.balanceOf(VESTING_MANAGER);

        assertEq(endingGranterBalance, startingGranterBalance + value);
        assertEq(endingOwnerBalance, startingOwnerBalance - value);
    }

    function testTransferFailsAfterPartialVestingDurationWhenamountExceedsTransferableBalance()
        public
    {
        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start,
            duration,
            20,
            true
        );
        vm.stopPrank();

        vm.expectRevert();
        vm.warp(start + duration + 90);
        vm.startPrank(Granter);
        vestToken.transfer(address(1), 400);
        vm.stopPrank();
    }

    function testCreateVestingScheduleIsSuccessfulWithDurationZero() public {
        uint256 startingAliceBalance = vestToken.balanceOf(ALICE);
        uint256 startingOwnerBalance = vestToken.balanceOf(VESTING_MANAGER);

        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            ALICE,
            value,
            start,
            duration,
            20,
            true
        );
        vm.stopPrank();
        uint256 endingAliceBalance = vestToken.balanceOf(ALICE);
        uint256 endingOwnerBalance = vestToken.balanceOf(VESTING_MANAGER);

        assertEq(endingAliceBalance, startingAliceBalance + value);
        assertEq(endingOwnerBalance, startingOwnerBalance - value);
    }

    function testcreateVestingScheduleFailsWhenMsgSenderIsNotOwner() public {
        vm.expectRevert(); // hey, the next line should revet/fail
        vm.startPrank(ALICE);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start,
            duration,
            20,
            true
        );
        vm.stopPrank();
    }

    // This test creates 9 vesting schedules, then a 10th (which should succeed), and then attempts an 11th (which should fail).
    function testVestingScheduleLimitEdgeCases() public {
        vm.startPrank(VESTING_MANAGER);

        // Create 9 vesting schedules
        for (uint256 i = 0; i < 9; i++) {
            vestToken.createVestingSchedule(
                ALICE,
                value,
                start + i,
                duration,
                20,
                true
            );
        }

        // Create 10th schedule (should succeed)
        vestToken.createVestingSchedule(
            ALICE,
            value,
            start + 9,
            duration,
            20,
            true
        );

        // Verify that Alice has exactly 10 vesting schedules
        VestingToken.GrantInfo[] memory grants = vestToken.getGrants(ALICE);
        assertEq(
            grants.length,
            10,
            "Alice should have exactly 10 vesting schedules"
        );

        // Attempt to create 11th schedule (should fail)
        vm.expectRevert("Cannot vest more than 10 times for a granter!");
        vestToken.createVestingSchedule(
            ALICE,
            value,
            start + 10,
            duration,
            20,
            true
        );

        vm.stopPrank();
    }

    function testcreateVestingScheduleFailsWithUnitIsMoreThan100() public {
        vm.expectRevert(); // hey, the next line should revet/fail
        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            address(0),
            value,
            start,
            duration,
            101,
            true
        );
        vm.stopPrank();
    }

    //////////////////// test  transfer  /////////////////////////////////

    function testTransferWithoutVesting() public {
        deal(address(vestToken), address(1), 20000);

        uint256 startingUser1Balance = vestToken.balanceOf(address(1));
        uint256 startingUser2Balance = vestToken.balanceOf(address(2));

        vm.startPrank(address(1));
        vestToken.transfer(address(2), value);
        vm.stopPrank();

        uint256 endingUser1Balance = vestToken.balanceOf(address(1));
        uint256 endingUser2Balance = vestToken.balanceOf(address(2));
        assertEq(endingUser1Balance, startingUser1Balance - value);

        assertEq(endingUser2Balance, startingUser2Balance + value);
    }

    function testTransferFailsBeforeVestingDuration() public {
        uint256 startingGranterBalance = vestToken.balanceOf(Granter);

        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start,
            duration,
            20,
            true
        );
        vm.stopPrank();

        // Move time forward to just before vesting period ends
        vm.expectRevert();
        vm.warp(start + duration - 1);
        vm.startPrank(Granter);
        vestToken.transfer(address(2), 20);
        vm.stopPrank();

        uint256 endingGranterBalance = vestToken.balanceOf(Granter);
        assertEq(endingGranterBalance, startingGranterBalance + value);
        // calculate transfable Tokens at start + duration
        assertEq(
            vestToken.transferableTokens(Granter),
            0,
            "All tokens should be transferable"
        );
    }

    function testTransferSuccessfulAfterFullVestingDuration() public {
        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start,
            duration,
            20,
            true
        );
        vm.stopPrank();

        uint256 startingRecipientBalance = vestToken.balanceOf(address(1));
        uint256 startingGranterBalance = vestToken.balanceOf(Granter);
        vm.warp(start + (3 * duration));
        vm.startPrank(Granter);
        vestToken.transfer(address(1), 100);
        vm.stopPrank();
        uint256 endingRecipientBalance = vestToken.balanceOf(address(1));
        uint256 endingGranterBalance = vestToken.balanceOf(Granter);

        assertEq(endingRecipientBalance, startingRecipientBalance + 100);
        assertEq(endingGranterBalance, startingGranterBalance - 100);

        // calculate transfable Tokens at start + 3 * duration. Note that Transfer was successful so granter balance at this time is 1000 - 100
        assertEq(
            vestToken.transferableTokens(Granter),
            900,
            "All tokens should be transferable"
        );
    }

    // each 15 seconds release 50 token, I tested it when 45 seconds passed from duration+start. so 150 token can be transfable.
    function testTransferSuccessfulAfterPartialVestingDuration() public {
        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start,
            duration,
            20,
            true
        );
        vm.stopPrank();

        uint256 startingRecipientBalance = vestToken.balanceOf(address(1));
        uint256 startingGranterBalance = vestToken.balanceOf(Granter);
        vm.warp(start + duration + 45);
        vm.startPrank(Granter);
        vestToken.transfer(address(1), 100);
        vm.stopPrank();
        uint256 endingRecipientBalance = vestToken.balanceOf(address(1));
        uint256 endingGranterBalance = vestToken.balanceOf(Granter);

        assertEq(endingRecipientBalance, startingRecipientBalance + 100);
        assertEq(endingGranterBalance, startingGranterBalance - 100);

        // calculate transfable Tokens at start + duration + 45. Note that Transfer was successful so gramter balance at this time is 150 - 100
        assertEq(
            vestToken.transferableTokens(Granter),
            100,
            "All tokens should be transferable"
        );
    }

    //////////////////////////////////////revokeVestingSchedule

    function testRevokeVestingScheduleSuccessfulAndGrantWasRemoved() public {
        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            ALICE,
            value,
            start,
            duration,
            20,
            true
        );

        uint256 grantIndex = 0;
        vestToken.revokeVestingSchedule(ALICE, grantIndex);
        vm.stopPrank();
        // check it has been removed from list of grants
        vm.expectRevert("Holder has no grants");
        vestToken.getGrants(ALICE);
    }

    function testRevokeVestingScheduleFailsForNonVestingManager() public {
        vm.prank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            ALICE,
            value,
            start,
            duration,
            20,
            true
        );

        uint256 grantIndex = 0;
        vm.expectRevert();
        vm.prank(BOB);
        vestToken.revokeVestingSchedule(ALICE, grantIndex);
    }

    function testRevokeVestingScheduleFailsForInvalidIndex() public {
        vm.prank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            ALICE,
            value,
            start,
            duration,
            20,
            true
        );

        uint256 invalidIndex = 1;
        vm.expectRevert();
        vm.prank(VESTING_MANAGER);
        vestToken.revokeVestingSchedule(ALICE, invalidIndex);
    }

    //////////////////////////////////////////////////////////

    function testCreateVestingScheduleIsSuccessfulWithMultipleVestingSchedule()
        public
    {
        uint256 startingGranterBalance = vestToken.balanceOf(Granter);
        uint256 startingOwnerBalance = vestToken.balanceOf(VESTING_MANAGER);

        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start,
            duration,
            20,
            true
        );
        vestToken.createVestingSchedule(
            Granter,
            2 * value,
            start + 300,
            duration,
            20,
            true
        );
        vestToken.createVestingSchedule(
            Granter,
            500,
            start + 600,
            duration,
            20,
            true
        );

        vm.stopPrank();
        uint256 endingGranterBalance = vestToken.balanceOf(Granter);
        uint256 endingOwnerBalance = vestToken.balanceOf(VESTING_MANAGER);

        assertEq(endingGranterBalance, startingGranterBalance + 3500);
        assertEq(endingOwnerBalance, startingOwnerBalance - 3500);
    }

    // after twice vesting schedule, granter has 50 on time 300, on 400
    //  0 seconds ----------100 seconds ----------300 seconds ----------- 400 sec
    // vesting schedule 1: 0 -----300 (1000 token)
    // vesting schedule 2: 100 -----400 (1000 token)
    // from vesting schedule 1: 300 ->50   315 -> 100 // 330 -> 150 // 345 -> 200 // 360 -> 250 // 375 -> 300 // 390 -> 350 // 405 -> 400 // 420 -> 450
    // from vesting schedule 21: 400 ->50   415 -> 100 // 430 -> 150
    // so in time block.timestamp + 400 + 30, transfableTokens are 600 and granter wants to transfer 640

    function testTransferFailsAfterPartialVestingDurationWhenamountExceedsTransferableBalanceWithMultipleVestingSchedule()
        public
    {
        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start,
            duration,
            20,
            true
        );
        vestToken.createVestingSchedule(
            Granter,
            value,
            start + 100,
            duration,
            20,
            true
        );
        vm.stopPrank();

        vm.expectRevert();
        vm.warp(block.timestamp + 400 + 30);
        vm.startPrank(Granter);
        vestToken.transfer(address(1), 640);
        vm.stopPrank();
    }

    function testTransferSuccessfulAfterPartialVestingDurationWithTwoGrants()
        public
    {
        uint256 value2 = 500;
        uint256 start1 = 0;
        uint256 start2 = 100;

        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start1,
            duration,
            20,
            true
        );
        vestToken.createVestingSchedule(
            Granter,
            value2,
            start2,
            duration,
            20,
            true
        );
        vm.stopPrank();

        uint256 startingRecipientBalance = vestToken.balanceOf(address(1));
        uint256 startingGranterBalance = vestToken.balanceOf(Granter);

        // Warp to 45 seconds after the end of the first vesting schedule
        vm.warp(duration + 45);

        // Calculate transferable tokens before transfer
        uint256 transferableBeforeTransfer = vestToken.transferableTokens(
            Granter
        );
        console.log(transferableBeforeTransfer);

        // Transfer a smaller amount that should definitely be available
        uint256 transferAmount = 150;
        vm.startPrank(Granter);
        vestToken.transfer(address(1), transferAmount);
        vm.stopPrank();

        uint256 endingRecipientBalance = vestToken.balanceOf(address(1));
        uint256 endingGranterBalance = vestToken.balanceOf(Granter);

        assertEq(
            endingRecipientBalance,
            startingRecipientBalance + transferAmount
        );
        assertEq(endingGranterBalance, startingGranterBalance - transferAmount);

        // Calculate transferable tokens after transfer
        uint256 transferableAfterTransfer = vestToken.transferableTokens(
            Granter
        );
        console.log(transferableAfterTransfer);

        // Assert that the difference in transferable tokens equals the transferred amount
        assertEq(
            transferableBeforeTransfer - transferableAfterTransfer,
            transferAmount,
            "Difference in transferable tokens should equal transferred amount"
        );
    }

    //////////////////// testGetGrant /////////////////////////////////

    function testGetGrantsWhenTimePassed() public {
        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            ALICE,
            value,
            start,
            duration,
            20,
            true
        );
        uint256 grantIndex = 0;
        vm.warp(start + 4 * duration);
        vestToken.revokeVestingSchedule(ALICE, grantIndex);
        vm.stopPrank();
        // check it has been removed from list of grants
        vm.expectRevert("Holder has no grants");
        vestToken.getGrants(ALICE);
    }

    //////////////////// test transferFrom   /////////////////////////////////

    function testTransferFromWithoutVesting() public {
        deal(address(vestToken), address(1), 20000);
        vm.prank(address(1));
        vestToken.approve(address(2), 10000);
        uint256 startingSpenderBalance = vestToken.balanceOf(address(3));
        uint256 startingOwnerBalance = vestToken.balanceOf(address(1));

        vm.startPrank(address(2));
        vestToken.transferFrom(address(1), address(3), 10000 / 2);
        vm.stopPrank();

        uint256 endingSpenderBalance = vestToken.balanceOf(address(3));
        uint256 endingOwnerBalance = vestToken.balanceOf(address(1));

        assertEq(vestToken.balanceOf(address(3)), 10000 / 2);
        assertEq(endingSpenderBalance, startingSpenderBalance + 10000 / 2);
        assertEq(endingOwnerBalance, startingOwnerBalance - 10000 / 2);
    }

    ////////////////granter has some grants and some tokens that be transfeered to them normally, check above sncenario completely.////

    function testCreateVestingScheduleIsSuccessfulWhileGranterHadSomeTokensBefore()
        public
    {
        deal(address(vestToken), Granter, 20000);

        uint256 startingGranterBalance = vestToken.balanceOf(Granter);
        uint256 startingOwnerBalance = vestToken.balanceOf(VESTING_MANAGER);

        vm.startPrank(VESTING_MANAGER);
        vestToken.createVestingSchedule(
            Granter,
            value,
            start,
            duration,
            20,
            true
        );
        vm.stopPrank();
        uint256 endingGranterBalance = vestToken.balanceOf(Granter);
        uint256 endingOwnerBalance = vestToken.balanceOf(VESTING_MANAGER);
        assertEq(startingGranterBalance, 20000);
        assertEq(endingGranterBalance, startingGranterBalance + value);
        assertEq(endingOwnerBalance, startingOwnerBalance - value);

        vm.warp(start + duration * 2);
        assertEq(
            vestToken.transferableTokens(Granter),
            value + 20000,
            "All tokens should be transferable"
        );

        vm.warp(start + duration - 1);
        assertEq(
            vestToken.transferableTokens(Granter),
            20000,
            "All tokens should be transferable"
        );
        vm.warp(start + duration);
        assertEq(
            vestToken.transferableTokens(Granter),
            20050,
            "All tokens should be transferable"
        );
    }
}
