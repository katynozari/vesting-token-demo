// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {VestingTokenManager} from "../src/VestingTokenManager.sol";

contract DeployVestingTokenManager is Script {
    address public owner;
    address public vestToken;

    function run() external returns (VestingTokenManager) {
        vm.startBroadcast();
        VestingTokenManager token = new VestingTokenManager(owner, vestToken);
        vm.stopBroadcast();
        return token;
    }
    function setAddresses(address _owner, address _vestToken) external {
        owner = _owner;
        vestToken = _vestToken;
    }
}
