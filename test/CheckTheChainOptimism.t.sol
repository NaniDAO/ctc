// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {CheckTheChainOptimism} from "../src/CheckTheChainOptimism.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "forge-std/console.sol";

contract CheckTheChainTest is Test {
    CheckTheChainOptimism internal ctc;

    address constant ORIGIN = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant UNI = 0x6fd9d7AD17242c41f7131d257212c54A0e816691;

    function setUp() public payable {
        vm.createSelectFork(vm.rpcUrl("opti"));
        ctc = new CheckTheChainOptimism();
    }

    function testCheckPriceWETH() public payable {
        (uint256 price, string memory strPrice) = ctc.checkPrice(WETH);
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

    function testCheckPriceDAI() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);
        console.log("DAI Price in USDC: ", price);
        console.log("DAI Price String: ", strPrice);
    }

    function testCheckPriceUSDT() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
        console.log("USDT Price in USDC: ", price);
        console.log("USDT Price String: ", strPrice);
    }

    function testCheckPriceLINKInETHToUSDC() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPriceInETHToUSDC(0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6);
        console.log("LINK Price in USDC: ", price);
        console.log("LINK Price String: ", strPrice);
    }

    function testCheckPriceWBTC() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
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
        address usdc = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;

        // Assume USDC is already registered in your setup
        (uint256 balance, string memory balanceAdjustedStr) = ctc.balanceOf(user, usdc);

        console.log("USDC Balance: ", balance);
        console.log("USDC Adjusted Balance String: ", balanceAdjustedStr);
    }

    function testUSDCTotalSupply() public view {
        address usdc = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;

        (uint256 supply, string memory supplyAdjustedStr) = ctc.totalSupply(usdc);

        console.log("USDC Total Supply: ", supply);
        console.log("USDC Adjusted Total Supply String: ", supplyAdjustedStr);
    }
}
