// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {CheckTheChain} from "../src/CheckTheChain.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "forge-std/console.sol";

contract CheckTheChainTest is Test {
    CheckTheChain internal ctc;

    address constant POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ARB = 0xB50721BCf8d664c30412Cfbc6cf7a15145234ad1;
    address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant NANI = 0x00000000000007C8612bA63Df8DdEfD9E6077c97;

    function setUp() public payable {
        vm.createSelectFork(vm.rpcUrl("main"));
        ctc = new CheckTheChain();
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
}
