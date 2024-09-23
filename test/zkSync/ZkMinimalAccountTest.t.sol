// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/zkSync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ZkMinimalAccountTest is Test {
    ZkMinimalAccount zkMinimalAccount;
    ERC20Mock usdc;

    function setUp() public {
        zkMinimalAccount = new ZkMinimalAccount();
        usdc = new ERC20Mock();
    }

    function testZkOwnerCanExceuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;

        // Act

        // Assert
    }
}
