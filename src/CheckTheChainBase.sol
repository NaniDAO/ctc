// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import {MetadataReaderLib} from "@solady/src/utils/MetadataReaderLib.sol";

/// @notice Check the chain price of liquid tokens. Uses UniswapV3 pools.
/// @dev `prices` are in terms of USDC or ETH. `priceStr` is formatted for UIs.
contract CheckTheChainBase {
    using MetadataReaderLib for address;

    event Registered(address indexed token);
    event OwnershipTransferred(address indexed from, address indexed to);

    address public owner = tx.origin; // Initialize with deployer.

    /// @dev The address of the USDC stablecoin token. Used for dollar prices.
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /// @dev The address of the wrapped ether token. Used for ether prices.
    address internal constant WETH = 0x4200000000000000000000000000000000000006;

    /// @dev The address of the Uniswap V3 Factory. This helps find the pools for prices.
    address internal constant UNISWAP_V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    /// @dev The Uniswap V3 Pool `initcodehash`.
    bytes32 internal constant UNISWAP_V3_POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    /// @dev The L2Resolver for `base.eth` domains.
    address internal constant BASE_ENS = 0xC6d566A56A1aFf6508b41f6c90ff131615583BCD;

    /// @dev The ReverseRegistrar for `base.eth` domains.
    address internal constant BASE_ENS_REVERSE = 0x79EA96012eEa67A83431F1701B3dFf7e37F9E282;

    /// @dev String mapping for `ENSAsciiNormalizer` logic.
    bytes internal constant ASCII_MAP =
        hex"2d00020101000a010700016101620163016401650166016701680169016a016b016c016d016e016f0170017101720173017401750176017701780179017a06001a010500";

    mapping(address asset => Token) public assets;
    mapping(string symbol => address) public addresses;

    address[] public registered;

    /// @dev Each index in idnamap refers to an ascii code point.
    /// If idnamap[char] > 2, char maps to a valid ascii character.
    /// Otherwise, idna[char] returns Rule.DISALLOWED or Rule.VALID.
    /// Modified from `ENSAsciiNormalizer` deployed by royalfork.eth
    /// (0x4A5cae3EC0b144330cf1a6CeAD187D8F6B891758).
    bytes1[] internal _idnamap;

    /// @dev `ENSAsciiNormalizer` rules.
    enum Rule {
        DISALLOWED,
        VALID
    }

    /// @dev Constructs this CTC on Ethereum with ENS `ASCII_MAP`.
    constructor() payable {
        unchecked {
            for (uint256 i; i != ASCII_MAP.length; i += 2) {
                bytes1 r = ASCII_MAP[i + 1];
                for (uint8 j; j != uint8(ASCII_MAP[i]); ++j) {
                    _idnamap.push(r);
                }
            }
        }
    }

    struct Token {
        string name;
        string symbol;
        uint8 decimals;
    }

    function register(address token) public onlyOwner {
        string memory name = token.readName();
        string memory symbol = token.readSymbol();
        assets[token] = Token(name, symbol, token.readDecimals());
        addresses[name] = token; // Reverse alias by token name.
        addresses[symbol] = token; // Reverse alias by token symbol.
        registered.push(token);
        emit Registered(token);
    }

    function getRegistered() public view returns (address[] memory tokens) {
        return registered;
    }

    function checkPrice(string calldata token)
        public
        view
        returns (uint256 price, string memory priceStr)
    {
        return checkPrice(addresses[token]);
    }

    function checkPriceInETH(string calldata token)
        public
        view
        returns (uint256 price, string memory priceStr)
    {
        return checkPriceInETH(addresses[token]);
    }

    function checkPriceInETHToUSDC(string calldata token)
        public
        view
        returns (uint256 price, string memory priceStr)
    {
        return checkPriceInETHToUSDC(addresses[token]);
    }

    function checkPrice(address token)
        public
        view
        returns (uint256 price, string memory priceStr)
    {
        uint256 factor = 10 ** token.readDecimals();
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
        uint256 factor = 10 ** token.readDecimals();
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

    function checkPriceInETHToUSDC(address token)
        public
        view
        returns (uint256 price, string memory priceStr)
    {
        (uint256 tokenPriceInETH,) = checkPriceInETH(token);
        (uint256 ethPriceInUSDC,) = checkPrice(WETH);
        price = (tokenPriceInETH * ethPriceInUSDC) / 10 ** token.readDecimals();
        priceStr = _convertWeiToString(price, 6);
    }

    function batchCheckPrices(address[] calldata tokens)
        public
        view
        returns (uint256[] memory prices, string[] memory priceStrs)
    {
        uint256 length = tokens.length;
        prices = new uint256[](length);
        priceStrs = new string[](length);

        for (uint256 i; i != length; ++i) {
            (prices[i], priceStrs[i]) = checkPrice(tokens[i]);
        }
    }

    function batchCheckPricesInETH(address[] calldata tokens)
        public
        view
        returns (uint256[] memory prices, string[] memory priceStrs)
    {
        uint256 length = tokens.length;
        prices = new uint256[](length);
        priceStrs = new string[](length);

        for (uint256 i; i != length; ++i) {
            (prices[i], priceStrs[i]) = checkPriceInETH(tokens[i]);
        }
    }

    function batchCheckPricesInETHToUSDC(address[] calldata tokens)
        public
        view
        returns (uint256[] memory prices, string[] memory priceStrs)
    {
        uint256 length = tokens.length;
        prices = new uint256[](length);
        priceStrs = new string[](length);

        for (uint256 i; i != length; ++i) {
            (prices[i], priceStrs[i]) = checkPriceInETHToUSDC(tokens[i]);
        }
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

    /// @dev Returns the amount of ERC20 `token` owned by `account`. From the Solady STL.
    function _balanceOf(address token, address account) internal view returns (uint256 amount) {
        assembly ("memory-safe") {
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

    error TotalSupplyQueryFailed();

    /// @dev Returns the total supply of the `token`. From the Solady STL.
    /// Reverts if the token does not exist or does not implement `totalSupply()`.
    function _totalSupply(address token) internal view returns (uint256 result) {
        assembly ("memory-safe") {
            mstore(0x00, 0x18160ddd) // `totalSupply()`.
            if iszero(
                and(gt(returndatasize(), 0x1f), staticcall(gas(), token, 0x1c, 0x04, 0x00, 0x20))
            ) {
                mstore(0x00, 0x54cd9435) // `TotalSupplyQueryFailed()`.
                revert(0x1c, 0x04)
            }
            result := mload(0x00)
        }
    }

    /// @dev Returns the balance of a user in token.
    function balanceOf(address user, address token)
        public
        view
        returns (uint256 balance, string memory balanceStr)
    {
        bool isEth = token == address(0);
        balance = isEth ? user.balance : _balanceOf(token, user);
        uint8 decimals = isEth ? 18 : token.readDecimals();
        balanceStr = _convertWeiToString(balance, decimals);
    }

    /// @dev Returns the total supply of a token.
    function totalSupply(address token)
        public
        view
        returns (uint256 supply, string memory supplyStr)
    {
        supply = _totalSupply(token);
        supplyStr = _convertWeiToString(supply, token.readDecimals());
    }

    error InvalidReceiver();

    /// @dev Returns ENS name ownership details.
    /// note: The `receiver` should be already set.
    function whatIsTheAddressOf(string calldata name)
        public
        view
        returns (address _owner, address receiver, bytes32 node)
    {
        node = _namehash(name);
        receiver = _owner = IENSHelper(BASE_ENS).addr(node);
        if (receiver == address(0)) revert InvalidReceiver();
    }

    /// @dev Returns ENS reverse name resolution details.
    function whatIsTheNameOf(address user) public view returns (string memory) {
        return IENSHelper(BASE_ENS).name(IENSHelper(BASE_ENS_REVERSE).node(user));
    }

    /// @dev Computes an ENS domain namehash.
    function _namehash(string memory domain) internal view returns (bytes32 node) {
        // Process labels (in reverse order for namehash).
        uint256 i = bytes(domain).length;
        uint256 lastDot = i;
        unchecked {
            for (; i != 0; --i) {
                bytes1 c = bytes(domain)[i - 1];
                if (c == ".") {
                    node = keccak256(abi.encodePacked(node, _labelhash(domain, i, lastDot)));
                    lastDot = i - 1;
                    continue;
                }
                require(c < 0x80);
                bytes1 r = _idnamap[uint8(c)];
                require(uint8(r) != uint8(Rule.DISALLOWED));
                if (uint8(r) > 1) {
                    bytes(domain)[i - 1] = r;
                }
            }
        }
        return keccak256(abi.encodePacked(node, _labelhash(domain, i, lastDot)));
    }

    /// @dev Computes an ENS domain labelhash given its start and end.
    function _labelhash(string memory domain, uint256 start, uint256 end)
        internal
        pure
        returns (bytes32 hash)
    {
        assembly ("memory-safe") {
            hash := keccak256(add(add(domain, 0x20), start), sub(end, start))
        }
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

interface IENSHelper {
    function addr(bytes32) external view returns (address);
    function node(address) external view returns (bytes32);
    function name(bytes32) external view returns (string memory);
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
