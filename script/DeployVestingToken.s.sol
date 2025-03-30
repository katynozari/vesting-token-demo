// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {VestingToken} from "../src/VestingToken.sol";

contract DeployVestingToken is Script {
    address public admin;
    address public vestingManager;

    function run() external returns (VestingToken) {
        vm.startBroadcast();
        VestingToken token = new VestingToken(admin, vestingManager);
        vm.stopBroadcast();
        return token;
    }
    function setAddresses(address _admin, address _vestingManager) external {
        admin = _admin;
        vestingManager = _vestingManager;
    }
}
