// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimalAccount} from "script/DeployMinimalAccount.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig config;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    address randomUser = makeAddr("randomUser");
    SendPackedUserOp sendPackedUserOp;

    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        DeployMinimalAccount deployer = new DeployMinimalAccount();
        (config, minimalAccount) = deployer.run();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // USDC Mint
    // msg.sender -> MinimalAccount
    // approve some amount
    // USDC contract
    // come from the entrypoint

    function testOwnerCanExecuteCommands() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        //Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        //Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCantExecuteCommands() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        //Act
        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public {
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(minimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, config.getConfig(), address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(config.getConfig().entryPoint).getUserOpHash(packedUserOp);
        // Act
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        // Assert
        assertEq(actualSigner, minimalAccount.owner());
    }

    function testUserFundsValidation() public {
        // 1. Sign user ops
        // 2. Call validate user ops
        // 3. Assert the return is correct
        //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(minimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, config.getConfig(), address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(config.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(config.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);

        // Assert
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        // //Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(minimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, config.getConfig(), address(minimalAccount));
        // bytes32 userOperationHash = IEntryPoint(config.getConfig().entryPoint).getUserOpHash(packedUserOp);

        vm.deal(address(minimalAccount), 1e18);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        //Act
        vm.prank(randomUser);
        IEntryPoint(config.getConfig().entryPoint).handleOps(ops, payable(randomUser));

        //assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
