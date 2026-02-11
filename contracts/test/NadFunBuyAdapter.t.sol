// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NadFunBuyAdapter} from "../src/adapters/NadFunBuyAdapter.sol";
import {INadFunRouter} from "../src/adapters/NadFunBuyAdapter.sol";
import {MockNadFunRouter} from "./mocks/MockNadFunRouter.sol";
import {CEOToken} from "../src/CEOToken.sol";

/// @title NadFunBuyAdapter unit tests
contract NadFunBuyAdapterTest is Test {
    NadFunBuyAdapter public adapter;
    MockNadFunRouter public mockRouter;
    CEOToken public ceoToken;

    address public recipient = makeAddr("recipient");

    function setUp() public {
        ceoToken = new CEOToken(1_000_000e18);
        mockRouter = new MockNadFunRouter(address(ceoToken));
        adapter = new NadFunBuyAdapter();

        vm.label(address(adapter), "NadFunBuyAdapter");
        vm.label(address(mockRouter), "MockNadFunRouter");
        vm.label(address(ceoToken), "CEOToken");
        vm.label(recipient, "recipient");
    }

    function test_receive_acceptsMon() public {
        vm.deal(address(this), 10 ether);
        (bool ok,) = address(adapter).call{value: 5 ether}("");
        assertTrue(ok);
        assertEq(address(adapter).balance, 5 ether);
    }

    function test_buyCeo_revert_whenNoBalance() public {
        vm.expectRevert(NadFunBuyAdapter.NoMonToBuy.selector);
        adapter.buyCeo(address(mockRouter), address(ceoToken), 1);
    }

    function test_buyCeo_forwardsValueToRouter() public {
        vm.deal(address(this), 10 ether);
        (bool ok,) = address(adapter).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(address(adapter).balance, 2 ether);

        uint256 minCeoOut = 1000e18;
        adapter.buyCeo(address(mockRouter), address(ceoToken), minCeoOut);

        assertEq(mockRouter.s_lastValue(), 2 ether);
        assertEq(mockRouter.s_lastAmountOutMin(), minCeoOut);
        assertEq(mockRouter.s_lastToken(), address(ceoToken));
        assertEq(mockRouter.s_lastTo(), address(this)); // hardened: always msg.sender
        assertEq(address(adapter).balance, 0);
    }

    function test_buyCeo_outputAlwaysToMsgSender() public {
        vm.deal(makeAddr("stranger"), 1 ether);
        vm.prank(makeAddr("stranger"));
        (bool ok,) = address(adapter).call{value: 1 ether}("");
        assertTrue(ok);

        vm.prank(makeAddr("stranger"));
        adapter.buyCeo(address(mockRouter), address(ceoToken), 0);

        assertEq(mockRouter.s_lastValue(), 1 ether);
        // Hardened: output goes to msg.sender (stranger), not a chosen recipient
        assertEq(mockRouter.s_lastTo(), makeAddr("stranger"));
    }
}
