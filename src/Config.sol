// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma experimental ABIEncoderV2;

import "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IERC20Detailed.sol";
import "./interfaces/IConfig.sol";
import "./interfaces/IOracle.sol";

contract Config is Ownable, IConfig, ReentrancyGuard {
    using Address for address;

    struct QuoteCurrency {
        uint256 id;
        address currency;
        uint256 currencyDecimal;
        address oracle;
        uint256 oracleDecimal;
    }

    // add protocol fee
    int128 public totalFeePercentage = 100000;
    int128 public protocolFee;
    address public protocolTreasury;

    // Global curve operational state
    bool public globalFrozen = false;
    bool public flashable = false;

    bool public globalGuarded = false;
    mapping (address => bool) public poolGuarded;

    uint256 public globalGuardAmt;
    mapping (address => uint256) public poolGuardAmt;
    mapping (address => uint256) public poolCapAmt;

    // mapping quote currencies
    mapping(uint256 => QuoteCurrency) public quoteCurrencies;
    mapping(uint256 => bool) public isQuoteAdded;
    mapping(address => bool) public isQuoteUsed;
    mapping(address => bool) public isOracleUsed;

    event GlobalFrozenSet(bool isFrozen);
    event FlashableSet(bool isFlashable);
    event TreasuryUpdated(address indexed newTreasury);
    event ProtocolFeeUpdated(address indexed treasury, int128 indexed fee);
    event GlobalGuardSet(bool isGuarded);
    event GlobalGuardAmountSet (uint256 amount);
    event PoolGuardSet (address indexed pool, bool isGuarded);
    event PoolGuardAmountSet (address indexed pool, uint256 guardAmount);
    event PoolCapSet (address indexed pool, uint256 cap);
    event NewQuoteAdded (address indexed quote, uint256 quoteDecimal, address indexed oracle, uint256 oracleDecimal);

    constructor (
        int128 _protocolFee,
        address _treasury) {
            require(totalFeePercentage >= _protocolFee, "CurveFactory/fee-cant-be-over-100%");
            require(_treasury != address(0), "CurveFactory/zero-address");
            protocolFee = _protocolFee;
            protocolTreasury = _treasury;
        }

    function getGlobalFrozenState() external view virtual override returns (bool) {
        return globalFrozen;
    }
    
    function getFlashableState() external view virtual override returns (bool) {
        return flashable;
    }

    function getProtocolFee() external view virtual override returns (int128) {
        return protocolFee;
    }

    function getProtocolTreasury() external view virtual override returns (address) {
        return protocolTreasury;
    }

    function setGlobalFrozen(bool _toFreezeOrNotToFreeze) external virtual override onlyOwner {
        emit GlobalFrozenSet(_toFreezeOrNotToFreeze);

        globalFrozen = _toFreezeOrNotToFreeze;
    }

    function toggleGlobalGuarded () external  virtual override onlyOwner nonReentrant {
        globalGuarded = !globalGuarded;
        emit GlobalGuardSet(globalGuarded);
    }

    function setPoolGuarded (address pool, bool guarded ) external  virtual override onlyOwner nonReentrant {
        poolGuarded[pool] = guarded;
        emit PoolGuardSet(pool, guarded);
    }

    function setGlobalGuardAmount (uint256 amount) external  virtual override onlyOwner nonReentrant {
        globalGuardAmt = amount - 1e6;
        emit GlobalGuardAmountSet (globalGuardAmt);
    }

    function setPoolCap (address pool, uint256 cap) external nonReentrant virtual override onlyOwner {
        poolCapAmt[pool] = cap;
        emit PoolCapSet(pool, cap);
    }

    function setPoolGuardAmount (address pool, uint256 amount) external nonReentrant virtual override onlyOwner {
        poolGuardAmt[pool] = amount - 1e6;
        emit PoolGuardAmountSet(pool, amount);
    }

    function isPoolGuarded (address pool) external view override returns (bool) {
        bool _poolGuarded = poolGuarded[pool];
        if(!_poolGuarded){
            return globalGuarded;
        }else{
            return true;
        }
    }

    function getPoolGuardAmount (address pool) external view override returns (uint256) {
        uint256 _poolGuardAmt = poolGuardAmt[pool];
        if(_poolGuardAmt == 0) {
            return globalGuardAmt;
        }else{
            return _poolGuardAmt;
        }
    }

    function getPoolCap (address pool) external view override returns (uint256) {
        return poolCapAmt[pool];
    }
    
    function setFlashable(bool _toFlashOrNotToFlash) external  virtual override onlyOwner nonReentrant {
        emit FlashableSet(_toFlashOrNotToFlash);

        flashable = _toFlashOrNotToFlash;
    }

    function updateProtocolTreasury(address _newTreasury) external  virtual override onlyOwner nonReentrant {
        require(_newTreasury != protocolTreasury, "CurveFactory/same-treasury-address");
        require(_newTreasury != address(0), "CurveFactory/zero-address");
        protocolTreasury = _newTreasury;
        emit TreasuryUpdated(protocolTreasury);
    }

    function updateProtocolFee(int128 _newFee) external virtual override onlyOwner nonReentrant {
        require(totalFeePercentage >= _newFee, "CurveFactory/fee-cant-be-over-100%");
        require(_newFee != protocolFee, "CurveFactory/same-protocol-fee");
        protocolFee = _newFee;
        emit ProtocolFeeUpdated(protocolTreasury, protocolFee);
    }

    function isNewPairValid (address _quote, address _oracle) public view override returns (bool) {
        return (isOracleUsed[_oracle] && isQuoteUsed[_quote]);
    }

    function addNewQuoteCurrency(address _quote, uint256 _quoteDecimal, address _oracle, uint256 _oracleDecimal) external override onlyOwner {
        uint256 id = uint256(keccak256(abi.encode(_quote, _oracle)));
        require(!isQuoteAdded[id], "quote already added");
        require(_quote.isContract(), "invalid quote");
        require(_oracle.isContract(), "invalid oracle");
        require(!isOracleUsed[_oracle], "oracle already used for other quote");
        require(!isQuoteUsed[_quote], "quote already used with another oracle");
        require(IOracle(_oracle).decimals() == _oracleDecimal, "invalid oracle decimal");
        require(IERC20Detailed(_quote).decimals() == _quoteDecimal, "invalid quote decimal");
        QuoteCurrency memory quoteCurreny;
        quoteCurreny.id = id;
        quoteCurreny.currency = _quote;
        quoteCurreny.currencyDecimal = _quoteDecimal;
        quoteCurreny.oracle = _oracle;
        quoteCurreny.oracleDecimal = _oracleDecimal;
        quoteCurrencies[id] = quoteCurreny;
        isQuoteAdded[id] = true;
        isQuoteUsed[_quote] = true;
        isOracleUsed[_oracle] = true;
        emit NewQuoteAdded(_quote, _quoteDecimal, _oracle, _oracleDecimal);
    }

    function removeQuoteCurrency(address _quote, address _oracle) external override onlyOwner {
        uint256 id = uint256(keccak256(abi.encode(_quote, _oracle)));
        require(isQuoteAdded[id], "quote is not added");
        delete isQuoteAdded[id];
        delete isQuoteUsed[_quote];
        delete isOracleUsed[_oracle];
    }
}