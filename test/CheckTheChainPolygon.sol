// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {CheckTheChainPolygon} from "../src/CheckTheChainPolygon.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "forge-std/console.sol";

contract CheckTheChainPolygonTest is Test {
    CheckTheChainPolygon internal ctc;

    address constant ORIGIN = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    address constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address constant UNI = 0xb33EaAd8d922B1083446DC23f610c2567fB5180f;

    function setUp() public payable {
        vm.createSelectFork(vm.rpcUrl("poly"));
        ctc = new CheckTheChainPolygon();
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
            ctc.checkPrice(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
        console.log("DAI Price in USDC: ", price);
        console.log("DAI Price String: ", strPrice);
    }

    function testCheckPriceUSDT() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
        console.log("USDT Price in USDC: ", price);
        console.log("USDT Price String: ", strPrice);
    }

    function testCheckPriceLINKInETHToUSDC() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPriceInETHToUSDC(0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39);
        console.log("LINK Price in USDC: ", price);
        console.log("LINK Price String: ", strPrice);
    }

    function testCheckPriceWBTC() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);
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
        address usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

        // Assume USDC is already registered in your setup
        (uint256 balance, string memory balanceAdjustedStr) = ctc.balanceOf(user, usdc);

        console.log("USDC Balance: ", balance);
        console.log("USDC Adjusted Balance String: ", balanceAdjustedStr);
    }

    function testUSDCTotalSupply() public view {
        address usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

        (uint256 supply, string memory supplyAdjustedStr) = ctc.totalSupply(usdc);

        console.log("USDC Total Supply: ", supply);
        console.log("USDC Adjusted Total Supply String: ", supplyAdjustedStr);
    }
}
