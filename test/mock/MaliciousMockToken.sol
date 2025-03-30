pragma solidity ^0.8.20;

import "./MockToken.sol";

contract MaliciousMockToken is MockToken {
    address public target;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) MockToken(name, symbol, initialSupply) {}

    function setTarget(address _target) external {
        target = _target;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        if (recipient == target) {
            // Attempt reentrancy
            (bool success, ) = target.call(
                abi.encodeWithSignature("withdrawToken()")
            );
            require(success, "Reentrancy failed");
        }
        return super.transfer(recipient, amount);
    }
}
