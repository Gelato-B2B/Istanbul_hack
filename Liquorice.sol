// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IChainlinkAggregator {
    function latestAnswer() external view returns (int256);
}

contract Liquorice {

    struct LendingPool {
        uint256 interestRate;
        uint256 capital; //in ETH
        uint256 loanDuration;
        uint256 punishmentFee;
        uint256 collateralRatio;
        address[] whitelist;
        address owner;
    }

    struct borrowers {
        uint256 collateral;
        uint256 lockedCollateral;
    }

    struct Order {
        uint256 amountIn;
        uint256 amountOut;
        uint256 validTo;
        address taker;
        bytes uid; 
    }     

    struct liquidationMarket {
        address lender;
        address borrower; 
        uint256 borrowedETH;
        uint256 lockedColalteral;       
    }

    address constant lockUSDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    mapping(uint256 => LendingPool) public lendingPools;
    mapping(address => borrowers) public poolBorrowers;
    mapping(bytes32 => bool) public invalidatedOrders;    

    uint256 public nextPoolId;

    bytes32 immutable DOMAIN_SEPARATOR; 

    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    ); 

    bytes32 constant ORDER_TYPEHASH = keccak256(
        "Order(uint256 amountIn,uint256 amountOut,address taker,bytes uid)"
    );

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256("Liquorice"), // contract name
                keccak256("1"), // Version
                block.chainid,
                address(this)
            )
        );
    }    

    //---------------------------------------------------------------------------------------
    //------Main functions----------------------------------------------------------
    //---------------------------------------------------------------------------------------

    function createLendingPool(
        uint256 _interestRate,
        uint256 _capital,
        uint256 _loanDuration,
        uint256 _punishmentFee,
        uint256 _collateralRatio,
        address[] memory _whitelist
    ) external payable {

        require(msg.value >= _capital, "Not enough ETH provided");
        require(_punishmentFee <= 100, "Punishment fee cannot exceed 100.");
        require(_collateralRatio <= 100, "Collateral ratio must be below 100.");
        require(_collateralRatio >= 1, "Collateral ratio must be higher than 1.");

        LendingPool memory newPool = LendingPool({
            interestRate: _interestRate,
            capital: _capital,
            loanDuration: _loanDuration,
            punishmentFee: _punishmentFee,
            collateralRatio: _collateralRatio,
            whitelist: _whitelist,
            owner: msg.sender
        });

        lendingPools[nextPoolId] = newPool;
        nextPoolId++;
    }

    function withdrawCapital(uint256 poolId, uint256 withdrawAmount) external {
        LendingPool storage pool = lendingPools[poolId];
        require(msg.sender == pool.owner, "Only the pool owner can withdraw capital.");
        require(withdrawAmount <= pool.capital, "Withdrawl request exceeds pool amount.");
        pool.capital -= withdrawAmount;
        payable(pool.owner).transfer(withdrawAmount);
    }

    function depositCollateral(uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        IERC20 usdcToken = IERC20(lockUSDC);
        require(usdcToken.transferFrom(msg.sender, address(this), amount), "Transfer failed.");
        poolBorrowers[msg.sender].collateral += amount;
    }

    function withdrawCollateral(uint256 amount) public {
        require(amount > 0, "amount needs to be higher than zero");
        require(poolBorrowers[msg.sender].collateral - poolBorrowers[msg.sender].lockedCollateral > amount, "Not enough available collateral");
        poolBorrowers[msg.sender].collateral -= amount;
        IERC20 usdcToken = IERC20(lockUSDC);
        require(usdcToken.transferFrom(address(this), msg.sender, amount), "Transfer failed.");
    }

    function settlement(Order memory _order, bytes memory _signature) external payable {
        bytes32 orderhash = _hashOrder(_order);
        address recsigner = recoverSigner(orderhash, _signature);          
        require(recsigner == _order.taker, "Ivalid signature");  

        //Checking that quote is not reused
        _invalidateOrder(orderhash);

        // swap

        payable(msg.sender).transfer(_order.amountIn);
        IERC20 usdcToken = IERC20(lockUSDC);
        require(usdcToken.transferFrom(msg.sender, address(this), _order.amountOut), "Transfer failed.");
    }



    //---------------------------------------------------------------------------------------
    //------Supplimentary functions----------------------------------------------------------
    //---------------------------------------------------------------------------------------



    function _invalidateOrder(bytes32 _hash) internal {
        require(!invalidatedOrders[_hash], "Invalid Order");
        invalidatedOrders[_hash] = true;
    }           
    
   //hashes order data
    function _hashOrder(Order memory _order) public pure returns (bytes32) {
        return keccak256(abi.encode(
            ORDER_TYPEHASH,
            _order.amountIn,
            _order.amountOut,            
            _order.taker,
            _order.uid
        ));
    }

    //generates final hash including domain separator to be signed by maker from received order hash
    function getEthSignedMessageHash(bytes32 _orderHash)
        public
        view
        returns (bytes32 hash)
    {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            _orderHash
        ));
    }

    //view function that can be called by test maker to generate hash that maker has to sign
    function generateEIP712Hash(Order memory _order) public view returns (bytes32) {
        return getEthSignedMessageHash(_hashOrder(_order));
    } 

    function recoverSigner(
        bytes32 _hash,
        bytes memory signature
    ) public view returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        bytes32 messageHash = getEthSignedMessageHash(_hash);

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        return ecrecover(messageHash, v, r, s);
    }

    function getEthUsdPrice() internal view returns(uint256) {
        // mainnet
        // address source = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

        // sepoila
        // address source = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

        // goerli
        address source = 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;

        IChainlinkAggregator ethUsdPriceFeed = IChainlinkAggregator(source);
        int256 ethUsdPrice = ethUsdPriceFeed.latestAnswer();
        return uint256(ethUsdPrice);
    }

    receive() external payable {}

}
