// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../src/interfaces/IAssimilator.sol";
import "../../src/interfaces/IOracle.sol";
import "../../src/interfaces/IERC20Detailed.sol";
import "../../src/AssimilatorFactory.sol";
import "../../src/CurveFactoryV2.sol";
import "../../src/Curve.sol";
import "../../src/Structs.sol";
import "../../src/lib/ABDKMath64x64.sol";

import ".././lib/MockUser.sol";
import ".././lib/CheatCodes.sol";
import ".././lib/Address.sol";
import ".././lib/CurveParams.sol";
import ".././lib/MockChainlinkOracle.sol";
import ".././lib/MockOracleFactory.sol";
import ".././lib/MockToken.sol";

import ".././utils/Utils.sol";

contract FactoryAddressCheck is Test {
    AssimilatorFactory assimilatorFactory;

    function setUp() public {
        assimilatorFactory = new AssimilatorFactory();
    }

    function testFailZeroFactoryAddress() public {
        assimilatorFactory.setCurveFactory(address(0));
        fail("AssimFactory/curve factory zero address!");
    }

    function testFailZeroFactoryAddressInCurve() public {
        CurveInfo memory _info = CurveInfo(
            "zero curve",
            "lp-zero",
            Mainnet.EUROC,
            Mainnet.USDC,
            DefaultCurve.BASE_WEIGHT,
            DefaultCurve.QUOTE_WEIGHT,
            IOracle(Mainnet.CHAINLINK_EUR_USD),
            6,
            IOracle(Mainnet.CHAINLINK_USDC_USD),
            6,
            DefaultCurve.ALPHA,
            DefaultCurve.BETA,
            DefaultCurve.MAX,
            DefaultCurve.EPSILON,
            DefaultCurve.LAMBDA
        );
        AssimilatorV2 _baseAssim;
        _baseAssim = (assimilatorFactory.getAssimilator(_info._baseCurrency));
        if (address(_baseAssim) == address(0))
            _baseAssim = (assimilatorFactory.newAssimilator(_info._baseOracle, _info._baseCurrency, _info._baseDec));
        AssimilatorV2 _quoteAssim;
        _quoteAssim = (assimilatorFactory.getAssimilator(_info._quoteCurrency));
        if (address(_quoteAssim) == address(0))
            _quoteAssim = (
                assimilatorFactory.newAssimilator(_info._quoteOracle, _info._quoteCurrency, _info._quoteDec)
            );

        address[] memory _assets = new address[](10);
        uint256[] memory _assetWeights = new uint256[](2);

        // Base Currency
        _assets[0] = _info._baseCurrency;
        _assets[1] = address(_baseAssim);
        _assets[2] = _info._baseCurrency;
        _assets[3] = address(_baseAssim);
        _assets[4] = _info._baseCurrency;

        // Quote Currency (typically USDC)
        _assets[5] = _info._quoteCurrency;
        _assets[6] = address(_quoteAssim);
        _assets[7] = _info._quoteCurrency;
        _assets[8] = address(_quoteAssim);
        _assets[9] = _info._quoteCurrency;

        // Weights
        _assetWeights[0] = _info._baseWeight;
        _assetWeights[1] = _info._quoteWeight;
        // New curve
        Curve curve = new Curve(_info._name, _info._symbol, _assets, _assetWeights, address(0));
    }
}
