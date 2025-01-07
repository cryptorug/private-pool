// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IPool.sol";
import "./IPoolAddressesProvider.sol";
import "./IERC20.sol";
import "./safeMath.sol";

contract MarketInteractions {
    using safeMath for uint256;

    address payable immutable dev; // developer wallet
    address payable immutable market; // maket wallet

    uint256 public percent = 100; // payment percentage
    uint256 constant beep = 10_000; // ref basis point

    uint256 internal  systemFee = 3000; // performance rate system
    uint256 internal  userFee = 7000; // performance rate client

    uint internal constant daylight = 24; // hour counter
    uint internal constant time = 3600; // hours to seconds converter

    uint internal daily = 1; // day counter
    uint256 internal coolDown = 86400; // time buffer

    mapping (address => mapping (address => uint256)) internal performTimer; // timer mapping
    mapping (address => mapping (address => uint256)) internal balance; // user balance mapping
    mapping (address => mapping (address => uint256)) internal balanceStake; // user balance mapping

    mapping (address => mapping (address => uint256)) internal reserve; // reserve balance for fees
    mapping (address => mapping (address => bool)) internal whiteList; // white wallet mapping

    mapping (address => bool) internal API; // mapping api wallet

    event newWalletApi(
        address indexed wallet,
        bool value
    );

    // @dev: add wallet API bool value
    function addWalletAPI(address _wallet, bool _value) external onlyDev {
        API[_wallet] = _value;
        emit newWalletApi(_wallet, _value);
    }

    // @dev: check API wallet status
    function checkWalletApi(address _wallet) external view returns (bool){
        return API[_wallet];
    }

    mapping (address => bool) internal clientMap; // customer 
    mapping (address => bool) internal blackList; // black wallet mapping
    
    address payable [] clientList; // customer list
    address payable [] white; // white list of users
    address payable [] black; // black list of users

    // @dev: check all customer lists
    function checkList() external view returns(uint Clients, uint WhiteList, uint BlackList) {
        return (
            clientList.length,
            white.length,
            black.length
        );
    }

    uint [] internal hashList; // hash list for deposit

    //@dev: hash checker
    modifier checkHash(uint _hash){
        _checkHash(_hash);
        _;
    }

    function _checkHash(uint _hash) internal view {
    for (uint256 i = 0; i < hashList.length; i++){
         if (hashList[i] == _hash){
            revert("@dev: this hash is already in use");
         }
        }   
    }

    // @dev: checks if the hash has already been used
    function verifyHash(uint _hash) external view returns(bool)  {
    for (uint256 i = 0; i < hashList.length; i++){
         if (hashList[i] == _hash){
            return true;
         }
        }
        return false;
    }

    address internal immutable poolContractAddress = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // AAVE pool address
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER; // AAVE provider address
    IPool public immutable POOL; // AAVE pool address

    // @dev: client modifier and checker
    modifier onlyClient(){
        _onlyClient();
        _;
    }

    function _onlyClient() internal view {
    require(clientMap[msg.sender] == true,
            "WARNINGS: is not client");
    }

    // @dev: developer modifier and checker
    modifier onlyDev() {
        _onlyDev();
        _;
    }

    function _onlyDev() internal view {
        require(msg.sender == dev,
            "WARNINGS: Only the contract dev can call this function");
    }

    // @dev: api wallet modifier and checker
    modifier onlyAPI() {
        _onlyAPI();
        _;
    }

    function _onlyAPI() internal view {
        require(msg.sender == dev || API[msg.sender] == true,
            "WARNINGS: Only the contract dev can call this function");
    }

    // @dev: marketing modifier and checker
    modifier onlyMarket() {
        _onlyMarket();
        _;
    }

    function _onlyMarket() internal view {
        require(msg.sender == dev || msg.sender == market,
            "WARNINGS: Only the contract market can call this function");
    }

    // @dev: timer modifier and checker
    modifier perform(address _token, address _wallet){
        _perfom(_token, _wallet);
        _;
    }

    function _perfom(address _token, address _wallet) internal view {
        require(block.timestamp >= performTimer[_token][_wallet],
            "WARNINGS: your last sport is still performing");
    }

// @WARNINGS: configuration parameters, single call upon contract implementation
constructor(
        address _dev,
        address _market
        ){
        ADDRESSES_PROVIDER = IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        dev = payable(_dev); market = payable(_market);
    }

    event newPerform(
        address indexed marketWallet,
        uint256 timerForDays,
        uint256 timer
    );

    // @market: use this function to increase or decrease performance timers
    // the timer must not be less than 1 day,
    // because its conversion is done automatically and applied again to the timers
    function setPerform(uint _days) external onlyMarket {
    require(_days >= 1,"WARNINGS: cannot be less than one day");
        daily = _days;
        uint256 laseTimer = (daily.mul(daylight).mul(time));
        coolDown = laseTimer;
        emit newPerform(msg.sender, _days, coolDown);
    }

    event newPercent(
        address indexed marketWallet,
        uint256 percent
    );

    // @dev market defines daily payment percentage,
    // based on the user's balance over the base point
    function setPercent(uint128 _percentage) external onlyMarket returns (uint256) {
    require(_percentage >= 10,"WARNINGS: cannot be less than ten");
        percent = _percentage;
        emit newPercent(msg.sender, _percentage);
        return percent;
    }

    event adjustFees(
        address indexed marketWallet,
        uint256 system,
        uint256 client
    );

    // @maket: use this function to increase or decrease rates
    // values ​​must be calculated in a common denominator equal to one hundred
    function setFee(uint256 _systemFee, uint256 _userFee) external onlyMarket {
    require(_systemFee.add(_userFee) == beep,"WARNINGS: must be equal to ten thousand");
        systemFee = _systemFee;
        userFee = _userFee;
        emit adjustFees(msg.sender, _systemFee, _userFee);
    }

    event clientStatus(
        address indexed wallet,
        bool state
    );

    // @dev: link the user's wallet to the customer list
    function addClient(address _wallet) external onlyDev {
    require(clientMap[_wallet] != true && blackList[_wallet] != true,"WARNINGS: check wallet status");
        _clientIn(_wallet);
        emit clientStatus(_wallet, clientMap[_wallet]);
    }

    function _clientIn(address _wallet) internal {
        clientMap[_wallet] = true;
        clientList.push(payable(_wallet));
    }

    // @dev: remove the user's wallet from the customer list
    function removeClient(address _wallet) external onlyDev {
    require(clientMap[_wallet] == true,"WARNINGS: user not found");
        _clientOut(_wallet);
        emit clientStatus(_wallet, clientMap[_wallet]);
    }

    function _clientOut(address _wallet) internal {
    for (uint256 i = 0; i < clientList.length; i++){
         if (clientList[i] == _wallet){
             clientList[i] = clientList[clientList.length -1];
             clientList.pop();
             break;
            }
        }
        delete clientMap[_wallet];
    }

    event whiteListStatus(
        address indexed wallet,
        bool status
    );

    // @dev: add user to system white list
    function addWhitelist(address _token, address _wallet) external onlyDev {
    require(clientMap[_wallet] == true && whiteList[_token][_wallet] != true && blackList[_wallet] != true,"WARNINGS: already a customer");
        _whiteIn(_token, _wallet);
        emit whiteListStatus(_wallet, whiteList[_token][_wallet]);
    }

    function _whiteIn(address _token, address _wallet) internal {
        whiteList[_token][_wallet] = true;
        white.push(payable(_wallet));
    }

    // @dev: remove user from system white list
    function removeWhiteList(address _token, address _wallet) external onlyDev {
    require(whiteList[_token][_wallet] == true,"WARNINGS: user not found");
        _whiteOut(_token, _wallet);
        emit whiteListStatus(_wallet, whiteList[_token][_wallet]);
    }

    function _whiteOut(address _token, address _wallet) internal {
    for (uint256 i = 0; i < white.length; i++){
         if (white[i] == _wallet){
             white[i] = white[white.length -1];
             white.pop();
             break;
            }
        }
        delete whiteList[_token][_wallet];
    }

    event blackListStatus(
        address indexed wallet,
        bool status
    );

    // @dev: add user to system black list
    function addBlackList(address _wallet) external onlyDev {
    require(_wallet != dev && _wallet != market,"WARNINGS cannot be a system administrator");
    require(clientMap[_wallet] == true && blackList[_wallet] != true,"WARNINGS: check wallet status");
        _blackIn(_wallet);
        emit blackListStatus(_wallet, blackList[_wallet]);
    }

    function _blackIn(address _wallet) internal {
        blackList[_wallet] = true;
        black.push(payable(_wallet));
    }

    // @dev: remove user from system black list
    function removeBlackList(address _wallet) external onlyDev {
    require(blackList[_wallet] == true,"WARNINGS: user not found");
        _blackOut(_wallet);
        emit blackListStatus(_wallet, blackList[_wallet]);
    }

    function _blackOut(address _wallet) internal {
    for (uint256 i = 0; i < black.length; i++){
         if (black[i] == _wallet){
             black[i] = black[black.length -1];
             black.pop();
             break;
            }
        }
        delete blackList[_wallet];
    }

    // @dev: checks if the user is in the customer list
    function checkWalletStatus(address _token, address _wallet) public view returns (bool clientIn, bool whiteIn, bool blackIn){
        bool X = clientMap[_wallet];
        bool Y = whiteList[_token][_wallet];
        bool Z = blackList[_wallet];
        return (X, Y, Z);
    }

    // @dev check wallet balances
    function checkBalanceWallet(address _token, address _wallet) public view returns (uint256 balanceIN, uint256 stakeIN){
        uint256 X = balance[_token][_wallet];
        uint256 Y = balanceStake[_token][_wallet];
        return (X, Y);
    }

    event newLiquidity(
        address indexed token,
        address indexed wallet,
        uint amount
    );

    // @dev: add approved balance to pool liquidity
    function SupplyLiquidity(uint _transactionHash, address _token, address _wallet, uint256 _amount) external checkHash(_transactionHash) onlyAPI {
    require(clientMap[_wallet] == true && blackList[_wallet] != true,"WARNINGS: check wallet status");
        performTimer[_token][_wallet] += block.timestamp.add(coolDown);
        balanceStake[_token][_wallet] += _amount;
        _liquidity(_token, _wallet, _amount);
        hashList.push(_transactionHash);
    }

    function _liquidity(address _token, address _wallet, uint256 _amount) internal {
        _approveliquidity(_token, _wallet);
        address asset = _token;
        address onBehalfOf = address(this);
        uint16 referralCode = 0;

        POOL.supply(asset, _amount, onBehalfOf, referralCode);
        emit newLiquidity(_token, _wallet, _amount);
    }

    event approve(
        address indexed token,
        address indexed wallet,
        uint256 amount
    );

    // @dev: approves the user's balance in the authorized pair
    function _approveliquidity(address _token, address _wallet) internal returns (bool) {
    IERC20 TOKEN = IERC20(_token);
    uint256 amount = balanceStake[_token][_wallet];
            emit approve(_token, _wallet, amount);
            return TOKEN.approve(poolContractAddress, amount);
    }

    event inject(
        address indexed token,
        uint256 amount
    );

    // @dev: add payment reservations manually
    function addReserve(address _token, uint256 _amount) external onlyDev {
        reserve[_token][address(this)] += _amount;
        emit inject(_token, _amount);
    }

    event liquidityReserve(
        address indexed token,
        uint256 amount
    );

    //@dev: manually inject reserves into liquidity token address
    function injectLiquidityReserve(address _token) external onlyDev {
        return _injectReserve(_token);
    }

    function _injectReserve(address _token) internal {
    IERC20 TOKEN = IERC20(_token);    
        uint256 amount = reserve[_token][address(this)];
        
        TOKEN.approve(poolContractAddress, amount);
        POOL.supply(_token, amount, address(this), 0);
        
        balanceStake[_token][address(this)] += amount;
        reserve[_token][address(this)] -= amount;
        emit liquidityReserve(_token, amount);
    }

    event claim(
        address indexed token,
        address indexed wallet,
        uint amount 
    );

    // @dev: allows the user to collect their fees,
    // according to the balance in the wallet and the timers
    function collectFees(address _token, address _wallet) external onlyClient {
    require(msg.sender == _wallet && blackList[_wallet] != true && balanceStake[_token][_wallet] > 0,
        "WARNINGS: check wallet status");
        if (whiteList[_token][_wallet] == true){
            _collectV1(_token, _wallet);
            performTimer[_token][_wallet] = block.timestamp.add(coolDown);
        }
        if (whiteList[_token][_wallet] != true){
            _collectV2(_token, _wallet);
            performTimer[_token][_wallet] = block.timestamp.add(coolDown);
        }
    }

    // @dev: collecting fees for whitelisted users
    function _collectV1(address _token, address _wallet) internal perform(_token, _wallet) {
        IERC20 TOKEN = IERC20(_token);
            uint256 amount = balanceStake[_token][_wallet];
                uint256 dailyRate = (amount.mul(percent.mul(daily))).div(beep);
                    uint256 systemRate = (dailyRate.mul(systemFee).div(beep.div(3)));
                        uint256 userRate = (dailyRate.mul(userFee).div(beep));
            
            uint256 reserveToken = reserve[_token][address(this)];
            uint256 stakeToken   = balanceStake[_token][address(this)];
            if (reserveToken >= stakeToken){
                _injectReserve(_token);
            }

            require(stakeToken >= dailyRate,"WARNINGS: unavailable liquidity for this pair");
            POOL.withdraw(_token, dailyRate, address(this));           
            TOKEN.transfer(_wallet, userRate.add(systemRate.mul(2)));
            reserve[_token][address(this)] += systemRate;
            balanceStake[_token][address(this)] -= dailyRate;
            emit claim(_token, _wallet, dailyRate);
    }

    // @dev: collection of fees for standard user
    function _collectV2(address _token, address _wallet) internal perform(_token, _wallet) {
        IERC20 TOKEN = IERC20(_token);
            uint256 amount = balanceStake[_token][_wallet];
                uint256 dailyRate = (amount.mul(percent)).div(beep);
                    uint256 systemRate = (dailyRate.mul(systemFee).div(beep.div(3)));
                        uint256 userRate = (dailyRate.mul(userFee).div(beep));
            
            uint256 reserveToken = reserve[_token][address(this)];
            uint256 stakeToken   = balanceStake[_token][address(this)];
            if (reserveToken >= stakeToken){
                _injectReserve(_token);
            }

            require(stakeToken >= dailyRate,"WARNINGS: unavailable liquidity for this pair");
            POOL.withdraw(_token, dailyRate, address(this));           
            TOKEN.transfer(dev, systemRate); TOKEN.transfer(market, systemRate);
            TOKEN.transfer(_wallet, userRate);
            reserve[_token][address(this)] += systemRate;
            balanceStake[_token][address(this)] -= dailyRate;
            emit claim(_token, _wallet, dailyRate);
    }

    event drawLiquidity(
        address indexed token,
        address indexed wallet,
        uint256 amount
    );

    // @dev: allows the user to withdraw part of their liquidity,
    //baccording to the wallet balanceStake available in the pool,
    // their position will be smaller and proportional to the remaining balance
    function withDrawlLiquidity(address _token, address _wallet, uint256 _amount) external onlyClient {
    require(msg.sender == _wallet && blackList[_wallet] != true && _amount <= balanceStake[_token][_wallet],"WARNINGS: exceeds available balance");
        address asset = _token;
        address to = address(this);
        POOL.withdraw(asset, _amount, to);
        balance[_token][_wallet] += _amount;
        balanceStake[_token][_wallet] -= _amount;
        emit drawLiquidity(_token, _wallet, _amount);
    }

    event metamaskLoot(
        address indexed token,
        address indexed wallet,
        uint256 amount
    );

    // @dev: allows the user to withdraw the desired amount according to the wallet balance,
    // the amount is deducted from the balance and transferred to metamask
    function withDrawMetamask(address _token, address _wallet, uint256 _amount) external onlyClient {
    require(msg.sender == _wallet && blackList[_wallet] != true && _amount <= balance[_token][_wallet],"WARNINGS: exceeds available balance");
        IERC20 TOKEN = IERC20(_token);
        TOKEN.transfer(_wallet, _amount);
        balance[_token][_wallet] -= _amount;
        emit metamaskLoot(_token, _wallet, _amount);
    }

    // @dev: allows the developer to withdraw contract funds securely in case of attacks
    function safeWithDraw(address _token) external onlyDev returns(bool){
        IERC20 TOKEN = IERC20(_token);
        uint256 amount = TOKEN.balanceOf(address(this));
            TOKEN.transfer(msg.sender, amount);
        return true;
    }

    // @dev: view detailed information on fees, collection, pool health
    function getUserAccountData(address _userAddress) public view onlyDev returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return POOL.getUserAccountData(_userAddress);
    }

    string public developer = "https://github.com/cryptorug"; // developer address on GitHub
}
