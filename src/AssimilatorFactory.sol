// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Address.sol";

import "./assimilators/AssimilatorV2.sol";
import "./interfaces/IAssimilatorFactory.sol";
import "./interfaces/IOracle.sol";

contract AssimilatorFactory is IAssimilatorFactory, Ownable {
    using Address for address;

    event NewAssimilator(
        address indexed caller,
        bytes32 indexed id,
        address indexed assimilator,
        address oracle,
        address token,
        address quote
    );
    event AssimilatorRevoked(
        address indexed caller,
        bytes32 indexed id,
        address indexed assimilator
    );
    event CurveFactoryUpdated(
        address indexed caller,
        address indexed curveFactory
    );
    mapping(bytes32 => AssimilatorV2) public assimilators;

    address public curveFactory;
    address public immutable wETH;
    address public immutable wETHOracle;

    modifier onlyCurveFactoryOrOwner() {
        require(
            msg.sender == curveFactory || msg.sender == owner(),
            "unauthorized"
        );
        _;
    }

    constructor(address _wETH, address _wEthOracle) {
        require(_wETH.isContract(), "AssimFactory/invalid wETH Contract");
        require(
            _wEthOracle.isContract(),
            "AssimFactory/invalid wETH Oracle Contract"
        );
        wETH = _wETH;
        wETHOracle = _wEthOracle;
    }

    function setCurveFactory(address _curveFactory) external onlyOwner {
        require(
            _curveFactory != address(0),
            "AssimFactory/curve factory zero address!"
        );
        curveFactory = _curveFactory;
        emit CurveFactoryUpdated(msg.sender, curveFactory);
    }

    function getAssimilator(
        address _token,
        address _quote
    ) external view override returns (AssimilatorV2) {
        bytes32 assimilatorID = keccak256(abi.encode(_token, _quote));
        return assimilators[assimilatorID];
    }

    function newAssimilator(
        address _quote,
        IOracle _oracle,
        address _token,
        uint256 _tokenDecimals
    ) external override onlyCurveFactoryOrOwner returns (AssimilatorV2) {
        bytes32 assimilatorID = keccak256(abi.encode(_token, _quote));
        if (address(assimilators[assimilatorID]) != address(0))
            revert("AssimilatorFactory/assimilator-already-exists");
        AssimilatorV2 assimilator = new AssimilatorV2(
            _quote,
            _oracle,
            _token,
            _tokenDecimals,
            IOracle(_oracle).decimals()
        );
        assimilators[assimilatorID] = assimilator;
        emit NewAssimilator(
            msg.sender,
            assimilatorID,
            address(assimilator),
            address(_oracle),
            _token,
            _quote
        );
        return assimilator;
    }

    function revokeAssimilator(
        address _token,
        address _quote
    ) external onlyOwner {
        bytes32 assimilatorID = keccak256(abi.encode(_token, _quote));
        address _assimAddress = address(assimilators[assimilatorID]);
        assimilators[assimilatorID] = AssimilatorV2(address(0));
        emit AssimilatorRevoked(
            msg.sender,
            assimilatorID,
            address(_assimAddress)
        );
    }
}
