// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CEOVaultSwapAdapter} from "../src/adapters/CEOVaultSwapAdapter.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/// @title CEOVaultSwapAdapter unit tests
contract CEOVaultSwapAdapterTest is Test {
    CEOVaultSwapAdapter public adapter;
    IPoolManager public poolManager;

    // Uniswap V4 PoolManager on Monad (used for deployment test; no actual swaps in unit test)
    address constant UNISWAP_POOL_MANAGER_MONAD = 0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e;

    function setUp() public {
        poolManager = IPoolManager(UNISWAP_POOL_MANAGER_MONAD);
        adapter = new CEOVaultSwapAdapter(poolManager);

        vm.label(address(adapter), "CEOVaultSwapAdapter");
        vm.label(address(poolManager), "PoolManager");
    }

    function test_deploy_setsPoolManager() public view {
        assertEq(address(adapter.poolManager()), address(poolManager));
    }

    function test_receive_acceptsEth() public {
        vm.deal(address(this), 10 ether);
        (bool ok,) = address(adapter).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(adapter).balance, 1 ether);
    }

    function test_executeActions_revert_whenInvalidData() public {
        bytes memory invalidData = hex"deadbeef";
        vm.expectRevert();
        adapter.executeActions(invalidData);
    }

    function test_executeActions_revert_whenMalformedParams() public {
        // Valid action bytes but malformed params (empty params array)
        bytes memory malformedData = abi.encode(hex"06", new bytes[](0));
        vm.expectRevert();
        adapter.executeActions(malformedData);
    }
}
