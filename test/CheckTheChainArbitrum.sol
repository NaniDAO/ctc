// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {CheckTheChainArbitrum} from "../src/CheckTheChainArbitrum.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "forge-std/console.sol";

contract CheckTheChainTest is Test {
    CheckTheChainArbitrum internal ctc;

    address constant ORIGIN = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address constant UNI = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;

    function setUp() public payable {
        vm.createSelectFork(vm.rpcUrl("arbi"));
        ctc = new CheckTheChainArbitrum();
    }

    function testCheckPriceWETH() public payable {
        (uint256 price, string memory strPrice) = ctc.checkPrice(WETH);
        console.log(price);
        console.log(strPrice);
    }

    function testCheckPriceARB() public payable {
        (uint256 price, string memory strPrice) = ctc.checkPrice(ARB);
        console.log(price);
        console.log(strPrice);
    }

    function testCheckPriceUNI() public payable {
        (uint256 price, string memory strPrice) = ctc.checkPrice(UNI);
        console.log(price);
        console.log(strPrice);
    }

    function testCheckPriceUNIInETH() public payable {
        (uint256 price, string memory strPrice) = ctc.checkPriceInETH(UNI);
        console.log(price);
        console.log(strPrice);
    }

    function testCheckPriceARBInETH() public payable {
        (uint256 price, string memory strPrice) = ctc.checkPriceInETH(ARB);
        console.log(price);
        console.log(strPrice);
    }

    function testCheckPriceDAI() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
        console.log("DAI Price in USDC: ", price);
        console.log("DAI Price String: ", strPrice);
    }

    function testCheckPriceUSDT() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
        console.log("USDT Price in USDC: ", price);
        console.log("USDT Price String: ", strPrice);
    }

    function testCheckPriceCOMPInETH() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPriceInETH(0x354A6dA3fcde098F8389cad84b0182725c6C91dE);
        console.log("COMP Price in ETH: ", price);
        console.log("COMP Price String: ", strPrice);
    }

    function testCheckPriceLINKInETHToUSDC() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPriceInETHToUSDC(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4);
        console.log("LINK Price in USDC: ", price);
        console.log("LINK Price String: ", strPrice);
    }

    function testCheckPriceWBTC() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
        console.log("WBTC Price in USDC: ", price);
        console.log("WBTC Price String: ", strPrice);
    }

    function testRegisterToken() public {
        vm.prank(ORIGIN);
        ctc.register(UNI);
        address registeredToken = ctc.addresses("UNI");
        require(registeredToken == UNI, "Token registration failed.");
        console.log("Registered token address: ", registeredToken);
    }

    function testBatchCheckPrices() public view {
        address[] memory tokens = new address[](3);
        tokens[0] = WETH;
        tokens[1] = ARB;
        tokens[2] = UNI;

        (uint256[] memory prices, string[] memory priceStrs) = ctc.batchCheckPrices(tokens);

        for (uint256 i = 0; i < tokens.length; i++) {
            console.log("Price for token ", tokens[i], ": ", prices[i]);
            console.log("Price string: ", priceStrs[i]);
        }
    }

    function testOwnershipTransfer() public {
        address newOwner = address(0x123);
        vm.prank(ORIGIN);
        ctc.transferOwnership(newOwner);
        // Verify ownership is transferred
        (bool success, bytes memory data) = address(ctc).call(abi.encodePacked(ctc.owner.selector));
        require(success && abi.decode(data, (address)) == newOwner, "Ownership transfer failed.");
        console.log("Ownership transferred to: ", newOwner);
    }

    function testNonExistentPool() public view {
        // This token should have no direct pool for testing error handling
        address noPoolToken = address(0xDEADBEEF);

        try ctc.checkPrice(noPoolToken) returns (uint256 price, string memory strPrice) {
            console.log("Unexpectedly found a price: ", price, strPrice);
        } catch {
            console.log("Correctly handled non-existent pool.");
        }
    }

    function testPriceWithStringAlias() public {
        vm.prank(ORIGIN);
        ctc.register(UNI); // Ensure the token is registered
        (uint256 price, string memory strPrice) = ctc.checkPrice("UNI");
        console.log("Price for UNI by alias: ", price);
        console.log("Price string: ", strPrice);
    }

    function testUSDCBalanceOf() public view {
        address user = 0x1C0Aa8cCD568d90d61659F060D1bFb1e6f855A20;
        address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

        // Assume USDC is already registered in your setup
        (uint256 balance, string memory balanceAdjustedStr) = ctc.balanceOf(user, usdc);

        console.log("USDC Balance: ", balance);
        console.log("USDC Adjusted Balance String: ", balanceAdjustedStr);
    }

    function testUSDCTotalSupply() public view {
        address usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

        (uint256 supply, string memory supplyAdjustedStr) = ctc.totalSupply(usdc);

        console.log("USDC Total Supply: ", supply);
        console.log("USDC Adjusted Total Supply String: ", supplyAdjustedStr);
    }
}
