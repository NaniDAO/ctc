// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {LibSort} from "@solady/src/utils/LibSort.sol";
import {MetadataReaderLib} from "@solady/src/utils/MetadataReaderLib.sol";

/// @notice Check the chain price of listed tokens. Uses UniswapV3 pools.
/// @dev `prices` are in terms of raw USDC. `priceStr` is formatted for UIs.
contract CheckTheChain {
    using MetadataReaderLib for address;

    event Registered(address indexed token);
    event OwnershipTransferred(address indexed from, address indexed to);

    address public owner = tx.origin; // Initialize with deployer.

    /// @dev The address of the USDC stablecoin token. Used for dollar prices.
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @dev The address of the wrapped ether token. Used for ether prices.
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev The address of the Uniswap V3 Factory. This helps find the pools for prices.
    address internal constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    /// @dev The Uniswap V3 Pool `initcodehash`.
    bytes32 internal constant UNISWAP_V3_POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    mapping(address asset => Token) public assets;
    mapping(string symbol => address) public addresses;

    address[] internal registered;

    constructor() payable {}

    struct Token {
        string name;
        string symbol;
        uint8 decimals;
    }

    function register(address token) public onlyOwner {
        string memory symbol = token.readSymbol();
        assets[token] = Token(token.readName(), symbol, token.readDecimals());
        addresses[symbol] = token; // Reverse alias by the symbol.
        registered.push(token);
        emit Registered(token);
    }

    function checkPrice(string calldata token)
        public
        view
        returns (uint256 price, string memory priceStr)
    {
        return checkPrice(addresses[token]);
    }

    function checkPrice(address token)
        public
        view
        returns (uint256 price, string memory priceStr)
    {
        uint256 factor = 1e18;
        (address pool, bool usdcFirst) = _computePoolAddress(USDC, token);
        if (!usdcFirst) {
            unchecked {
                (uint160 sqrtPriceX96,,,,,,) = IUniswapV3PoolState(pool).slot0();
                price = (uint256(sqrtPriceX96) ** 2 * factor) >> (96 * 2);
            }
        } else {
            unchecked {
                (uint160 sqrtPriceX96,,,,,,) = IUniswapV3PoolState(pool).slot0();
                price = (factor * (1 << (96 * 2))) / (uint256(sqrtPriceX96) ** 2);
            }
        }
        priceStr = _convertWeiToString(price, 6);
    }

    function checkPriceInETH(address token)
        public
        view
        returns (uint256 price, string memory priceStr)
    {
        uint256 factor = 1e18;
        (address pool, bool wethFirst) = _computePoolAddress(WETH, token);
        if (!wethFirst) {
            unchecked {
                (uint160 sqrtPriceX96,,,,,,) = IUniswapV3PoolState(pool).slot0();
                price = (uint256(sqrtPriceX96) ** 2 * factor) >> (96 * 2);
            }
        } else {
            unchecked {
                (uint160 sqrtPriceX96,,,,,,) = IUniswapV3PoolState(pool).slot0();
                price = (factor * (1 << (96 * 2))) / (uint256(sqrtPriceX96) ** 2);
            }
        }
        priceStr = _convertWeiToString(price, 18);
    }

    function _convertWeiToString(uint256 weiAmount, uint256 decimals)
        internal
        pure
        returns (string memory)
    {
        unchecked {
            uint256 scalingFactor = 10 ** decimals;

            string memory wholeNumberStr = _toString(weiAmount / scalingFactor);
            string memory decimalPartStr = _toString(weiAmount % scalingFactor);

            while (bytes(decimalPartStr).length != decimals) {
                decimalPartStr = string(abi.encodePacked("0", decimalPartStr));
            }

            decimalPartStr = _removeTrailingZeros(decimalPartStr);

            if (bytes(decimalPartStr).length == 0) {
                return wholeNumberStr;
            }

            return string(abi.encodePacked(wholeNumberStr, ".", decimalPartStr));
        }
    }

    function _removeTrailingZeros(string memory str) internal pure returns (string memory) {
        unchecked {
            bytes memory strBytes = bytes(str);
            uint256 end = strBytes.length;

            while (end != 0 && strBytes[end - 1] == "0") {
                --end;
            }

            bytes memory trimmedBytes = new bytes(end);
            for (uint256 i; i != end; ++i) {
                trimmedBytes[i] = strBytes[i];
            }

            return string(trimmedBytes);
        }
    }

    function _toString(uint256 value) internal pure returns (string memory str) {
        assembly ("memory-safe") {
            str := add(mload(0x40), 0x80)
            mstore(0x40, add(str, 0x20))
            mstore(str, 0)
            let end := str
            let w := not(0)
            for { let temp := value } 1 {} {
                str := add(str, w)
                mstore8(str, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            let length := sub(end, str)
            str := sub(str, 0x20)
            mstore(str, length)
        }
    }

    /// @dev The `swap()` pool liquidity struct.
    struct SwapLiq {
        address pool;
        uint256 liq;
    }

    /// @dev Computes the create2 address for given token pair.
    /// note: This process checks all available pools for price.
    function _computePoolAddress(address tokenA, address tokenB)
        internal
        view
        returns (address pool, bool zeroForOne)
    {
        if (tokenA < tokenB) zeroForOne = true;
        else (tokenA, tokenB) = (tokenB, tokenA);
        address pool100 = _computePairHash(tokenA, tokenB, 100); // Lowest fee.
        address pool500 = _computePairHash(tokenA, tokenB, 500); // Lower fee.
        address pool3000 = _computePairHash(tokenA, tokenB, 3000); // Mid fee.
        address pool10000 = _computePairHash(tokenA, tokenB, 10000); // Hi fee.
        SwapLiq memory topPool;
        uint256 liq;
        if (pool100.code.length != 0) {
            liq = _balanceOf(tokenA, pool100);
            topPool = SwapLiq(pool100, liq);
        }
        if (pool500.code.length != 0) {
            liq = _balanceOf(tokenA, pool500);
            if (liq > topPool.liq) {
                topPool = SwapLiq(pool500, liq);
            }
        }
        if (pool3000.code.length != 0) {
            liq = _balanceOf(tokenA, pool3000);
            if (liq > topPool.liq) {
                topPool = SwapLiq(pool3000, liq);
            }
        }
        if (pool10000.code.length != 0) {
            liq = _balanceOf(tokenA, pool10000);
            if (liq > topPool.liq) {
                topPool = SwapLiq(pool10000, liq);
            }
        }
        pool = topPool.pool; // Return top pool.
    }

    /// @dev Computes the create2 deployment hash for a given token pair.
    function _computePairHash(address token0, address token1, uint24 fee)
        internal
        pure
        returns (address pool)
    {
        bytes32 salt = _hash(token0, token1, fee);
        assembly ("memory-safe") {
            mstore8(0x00, 0xff) // Write the prefix.
            mstore(0x35, UNISWAP_V3_POOL_INIT_CODE_HASH)
            mstore(0x01, shl(96, UNISWAP_V3_FACTORY))
            mstore(0x15, salt)
            pool := keccak256(0x00, 0x55)
            mstore(0x35, 0) // Restore overwritten.
        }
    }

    /// @dev Returns `keccak256(abi.encode(value0, value1, value2))`.
    function _hash(address value0, address value1, uint24 value2)
        internal
        pure
        returns (bytes32 result)
    {
        assembly ("memory-safe") {
            let m := mload(0x40)
            mstore(m, value0)
            mstore(add(m, 0x20), value1)
            mstore(add(m, 0x40), value2)
            result := keccak256(m, 0x60)
        }
    }

    /// @dev Returns the amount of ERC20 `token` owned by `account`.
    /*function _balanceOf(address token, address account) internal view returns (uint256 amount) {
        assembly ("memory-safe") {
            mstore(0x00, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            mstore(0x14, account) // Store the `account` argument.
            pop(staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20))
            amount := mload(0x20)
        }
    }*/

    function _balanceOf(address token, address account) internal view returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, account) // Store the `account` argument.
            mstore(0x00, 0x70a08231000000000000000000000000) // `balanceOf(address)`.
            amount :=
                mul( // The arguments of `mul` are evaluated from right to left.
                    mload(0x20),
                    and( // The arguments of `and` are evaluated from right to left.
                        gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                        staticcall(gas(), token, 0x10, 0x24, 0x20, 0x20)
                    )
                )
        }
    }

    /// @notice Get registered tokens sorted by their market cap (price * supply).
    /// @return sorted Array of token addresses sorted by market cap (descending).
    function getTopTokens() public view returns (address[] memory sorted) {
        uint256 len = registered.length;

        sorted = new address[](len);
        uint256[] memory values = new uint256[](len);

        address token;

        // Calculate market caps and prepare arrays.
        unchecked {
            for (uint256 i; i != len; ++i) {
                token = registered[i];
                sorted[i] = token;

                // Calculate market cap.
                (uint256 price,) = checkPrice(token);
                values[i] = price * _totalSupply(token);
            }
        }

        // Manual sort by market cap (descending).
        unchecked {
            for (uint256 i; i != len - 1; ++i) {
                for (uint256 j; j != len - i - 1; ++j) {
                    if (values[j] < values[j + 1]) {
                        // Swap values.
                        (values[j], values[j + 1]) = (values[j + 1], values[j]);
                        // Swap addresses.
                        (sorted[j], sorted[j + 1]) = (sorted[j + 1], sorted[j]);
                    }
                }
            }
        }
    }

    /// @notice Get top N tokens with their details.
    /// @param limit Maximum number of tokens to return (0 for all).
    /// @return tokens Array of token addresses.
    /// @return symbols Array of token symbols.
    /// @return marketCaps Array of market caps in USDC terms.
    function getTopTokensDetailed(uint256 limit)
        public
        view
        returns (address[] memory tokens, string[] memory symbols, uint256[] memory marketCaps)
    {
        address[] memory sorted = getTopTokens();
        uint256 len = sorted.length;
        uint256 size = limit == 0 || limit > len ? len : limit;

        tokens = new address[](size);
        symbols = new string[](size);
        marketCaps = new uint256[](size);

        unchecked {
            for (uint256 i; i != size; ++i) {
                address token = sorted[i];
                tokens[i] = token;
                symbols[i] = assets[token].symbol;

                (uint256 price,) = checkPrice(token);
                marketCaps[i] = price * _totalSupply(token);
            }
        }
    }

    /// @dev Returns the total supply of ERC20 `token`.
    function _totalSupply(address token) internal view returns (uint256 supply) {
        assembly ("memory-safe") {
            mstore(0x00, 0x18160ddd) // `totalSupply()`.
            if iszero(staticcall(gas(), token, 0x1c, 0x04, 0x20, 0x20)) {
                revert(codesize(), codesize())
            }
            supply := mload(0x20)
        }
    }

    /// @dev Returns the balance of a user in token.
    function balanceOf(address user, address token)
        public
        view
        returns (uint256 balance, uint256 balanceAdjusted)
    {
        bool isEth = token == address(0);
        balance = isEth ? user.balance : _balanceOf(token, user);
        balanceAdjusted = balance / 10 ** (isEth ? 18 : token.readDecimals());
    }

    /// @dev Returns the total supply of a token.
    function totalSupply(address token)
        public
        view
        virtual
        returns (uint256 supply, uint256 supplyAdjusted)
    {
        supply = _totalSupply(token);
        supplyAdjusted = supply / 10 ** token.readDecimals();
    }

    function transferOwnership(address to) public payable onlyOwner {
        emit OwnershipTransferred(msg.sender, owner = to);
    }

    error Unauthorized();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
}

interface IUniswapV3PoolState {
    function token0() external view returns (address);
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}
