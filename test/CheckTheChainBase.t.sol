// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {CheckTheChainBase} from "../src/CheckTheChainBase.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "forge-std/console.sol";

contract CheckTheChainBaseTest is Test {
    CheckTheChainBase internal ctc;

    address constant ORIGIN = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant UNI = 0xc3De830EA07524a0761646a6a4e4be0e114a3C83;

    function setUp() public payable {
        vm.createSelectFork(vm.rpcUrl("base"));
        ctc = new CheckTheChainBase();
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
            ctc.checkPrice(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);
        console.log("DAI Price in USDC: ", price);
        console.log("DAI Price String: ", strPrice);
    }

    function testCheckPriceUSDT() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2);
        console.log("USDT Price in USDC: ", price);
        console.log("USDT Price String: ", strPrice);
    }

    function testCheckPriceWBTC() public payable {
        (uint256 price, string memory strPrice) =
            ctc.checkPrice(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
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
