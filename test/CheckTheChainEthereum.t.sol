// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {CheckTheChainEthereum} from "../src/CheckTheChainEthereum.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "forge-std/console.sol";

contract CheckTheChainTest is Test {
    CheckTheChainEthereum internal ctc;

    address constant ORIGIN = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    address constant POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ARB = 0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1;
    address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant NANI = 0x00000000000007C8612bA63Df8DdEfD9E6077c97;

    function setUp() public payable {
        vm.createSelectFork(vm.rpcUrl("main"));
        ctc = new CheckTheChainEthereum();
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

    function testCheckPriceNANIInETH() public payable {
        (uint256 price, string memory strPrice) = ctc.checkPriceInETH(NANI);
        console.log(price);
        console.log(strPrice);
    }

    function testCheckPriceNANIInETHToUSDC() public payable {
        (uint256 price, string memory strPrice) = ctc.checkPriceInETHToUSDC(NANI);
        console.log(price);
        console.log(strPrice);
    }

    function testCheckPriceDAI() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        console.log("DAI Price in USDC: ", price);
        console.log("DAI Price String: ", strPrice);
    }

    function testCheckPriceUSDT() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        console.log("USDT Price in USDC: ", price);
        console.log("USDT Price String: ", strPrice);
    }

    function testCheckPriceCOMPInETH() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPriceInETH(0xc00e94Cb662C3520282E6f5717214004A7f26888);
        console.log("COMP Price in ETH: ", price);
        console.log("COMP Price String: ", strPrice);
    }

    function testCheckPriceLINKInETHToUSDC() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPriceInETHToUSDC(0x514910771AF9Ca656af840dff83E8264EcF986CA);
        console.log("LINK Price in USDC: ", price);
        console.log("LINK Price String: ", strPrice);
    }

    function testCheckPriceMKR() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2);
        console.log("MKR Price in USDC: ", price);
        console.log("MKR Price String: ", strPrice);
    }

    function testCheckPriceWBTC() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
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
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        // Assume USDC is already registered in your setup
        (uint256 balance, string memory balanceAdjustedStr) = ctc.balanceOf(user, usdc);

        console.log("USDC Balance: ", balance);
        console.log("USDC Adjusted Balance String: ", balanceAdjustedStr);
    }

    function testUSDCTotalSupply() public view {
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        (uint256 supply, string memory supplyAdjustedStr) = ctc.totalSupply(usdc);

        console.log("USDC Total Supply: ", supply);
        console.log("USDC Adjusted Total Supply String: ", supplyAdjustedStr);
    }

    function testNANIBalanceOf() public view {
        address user = 0x1C0Aa8cCD568d90d61659F060D1bFb1e6f855A20;

        // Assume USDC is already registered in your setup.
        (uint256 balance, string memory balanceAdjustedStr) = ctc.balanceOf(user, NANI);

        console.log("NANI Balance: ", balance);
        console.log("NANI Adjusted Balance String: ", balanceAdjustedStr);
    }

    function testNANITotalSupply() public view {
        (uint256 supply, string memory supplyAdjustedStr) = ctc.totalSupply(NANI);

        console.log("NANI Total Supply: ", supply);
        console.log("NANI Adjusted Total Supply String: ", supplyAdjustedStr);
    }

    function testWhatIsTheAddressOf() public view {
        string memory ensName = "z0r0z.eth";

        try ctc.whatIsTheAddressOf(ensName) returns (address _owner, address receiver, bytes32 node)
        {
            console.log("ENS Name:", ensName);
            console.log("Resolved Owner Address:", _owner);
            console.log("Resolved Receiver Address:", receiver);
            node = node;
        } catch (bytes memory reason) {
            console.log("Failed to resolve ENS name:", string(reason));
        }
    }

    function testWhatIsTheNameOf() public view {
        address ethAddress = 0x1C0Aa8cCD568d90d61659F060D1bFb1e6f855A20;

        try ctc.whatIsTheNameOf(ethAddress) returns (string memory ensName) {
            console.log("Ethereum Address:", ethAddress);
            console.log("Resolved ENS Name:", ensName);
        } catch (bytes memory reason) {
            console.log("Failed to resolve ENS name for address:", string(reason));
        }
    }
}
