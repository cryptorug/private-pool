// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IPool.sol";
import "./IPoolAddressesProvider.sol";
import "./IERC20.sol";
import "./safeMath.sol";

abstract contract MarketInteractions {
    using safeMath for uint256;

    address payable market;    
    address payable    dev;

    uint256 private  systemFee = 30;
    uint256 private  maxSpread = 24;
    uint256 private  coolDown = 86400;

    mapping (address => uint256) private performTimer;
    mapping (address => uint256) private balances;
    mapping (address => bool) private clientMap;

    address payable [] clientList;
    
    address private immutable aUSDT = 0x6ab707Aca953eDAeFBc4fD23bA73294241490620;
    address private immutable USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;

    address private liquidityAddress;
    IERC20  private liquidity;

    modifier onlyDev() {
        _onlyDev();
        _;
    }

    function _onlyDev() private view {
        require(msg.sender == dev,
            "@dev: Only the contract dev can call this function");
    }

    modifier onlyMarket() {
        _onlyMarket();
        _;
    }

    function _onlyMarket() private view {
        require(msg.sender == market,
            "@dev: Only the contract market can call this function");
    }

    modifier perform(){
        _perfom();
        _;
    }

    function _perfom() private view {
    if (clientMap[msg.sender]){
        require(block.timestamp >= performTimer[msg.sender],
            "@dev: your last sport is still performing");}
    }

    event claim(
        address indexed to,
        uint256 indexed amount
    );

constructor(
        address _addressProvider,
        address _dev,
        address _market
        ){
        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        dev = payable(_dev); market = payable(_market);
        performTimer[msg.sender] = block.timestamp + coolDown;
        liquidityAddress = USDT;
        liquidity = IERC20(USDT);
    }

    event newDeposit(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event clientStatus(
        address indexed wallet,
        bool indexed state
    );

    function addClient(address _wallet) external onlyDev {
        _clientIn(_wallet);
        emit clientStatus(_wallet, clientMap[_wallet]);
    }

    function removeClient(address _wallet) external onlyDev {
        _clientOut(_wallet);
        emit clientStatus(_wallet, clientMap[_wallet]);
    }

    function checkClient(address _wallet) external view onlyDev returns (bool){
        return clientMap[_wallet];
    }

    function checkbalances(address _wallet) external view onlyDev returns (uint256){
        return balances[_wallet];
    }

    function _clientIn(address _wallet) private {
        clientMap[_wallet] = true;
        clientList.push(payable(_wallet));
    }

    function _clientOut(address _wallet) private {
    for (uint256 i = 0; i < clientList.length; i++){
         if (clientList[i] == _wallet){
             clientList[i] = clientList[clientList.length -1];
             clientList.pop();
             break;
            }
        }
        delete clientMap[_wallet];
    }

    event approve(
        address indexed client,
        uint256 indexed amount
    );

    function _approveliquidity(address _wallet) private returns (bool) {
    address poolContractAddress = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    uint256 balance = balances[_wallet];
            emit approve(_wallet, balance);
            return liquidity.approve(poolContractAddress, balance);
    }

    event newLiquidity(
        address indexed pair,
        uint indexed amount
    );

    function SupplyLiquidity(address _wallet) external onlyDev {
        _supplyLiquidity(_wallet);
    }

    function _supplyLiquidity(address _wallet) private {
        address asset = liquidityAddress;
        uint256 amount = balances[_wallet];
        address onBehalfOf = address(this);
        uint16 referralCode = 0;

        POOL.supply(asset, amount, onBehalfOf, referralCode);
        emit newLiquidity(liquidityAddress, amount);
    }

    function getLiquidityPair() external view onlyDev returns (address){
        return liquidityAddress;
    }

    function allowanceliquidity() external view onlyDev returns (uint256) {
        return liquidity.allowance(address(this), address(this));
    }

    function getBalance(address _tokenAddress) external view onlyDev returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function withdrawlLiquidity(address _wallet) private onlyDev returns (uint256){
    autoPair();
        address asset = liquidityAddress;
        uint256 amount = balances[_wallet];
        address to = address(this);

        return POOL.withdraw(asset, amount, to);
    }

    event swap(
        address indexed swapFromPair,
        address indexed to
    );

    function manualPairExchange() external onlyDev {
        return autoPair();
    }

    function autoPair() private {
        if (liquidityAddress != aUSDT){
            liquidityAddress = aUSDT;
            liquidity = IERC20(aUSDT);
            emit swap(USDT, liquidityAddress);
            }else{
                if (liquidityAddress != USDT){
                    liquidityAddress = USDT;
                    liquidity = IERC20(USDT);
                    emit swap(aUSDT, liquidityAddress);
            }
        }
    }

    function safeWithDraw(address _token) external onlyDev returns(bool){
        IERC20 token = IERC20(_token);
        token.transfer(msg.sender, token.balanceOf(address(this)));
        return true;
    }

    event newLoot(
        uint256 indexed amount,
        address indexed wallet
    );

    function withdraw( address _wallet) external onlyDev {
        IERC20 token = IERC20(liquidityAddress);
        uint256 amount = balances[_wallet];
        token.transfer(_wallet, amount);
        balances[_wallet] -= amount;
        emit newLoot( amount, _wallet);
    }

    function getUserAccountData(address _userAddress) external view onlyDev returns (
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
}