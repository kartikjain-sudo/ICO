// SPDX-License-Identifier: None
pragma solidity ^0.8.0;


interface ERC20Interface {
    function transfer(address to, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function approve(address spender, uint tokens) external returns (bool success);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function totalSupply() external view returns(uint);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract ERC20Token is ERC20Interface {

    string public name;
    string public symbol;
    uint8 public decimals;
    uint public override totalSupply;

    mapping(address => uint) internal balances;
    mapping(address => mapping(address => uint)) internal allowed;
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint _totalSupply) {
            name = _name;
            symbol = _symbol;
            decimals = _decimals;
            totalSupply = _totalSupply;
            balances[msg.sender] = _totalSupply;
        }
        
    function transfer(address to, uint value) public override returns(bool) {
        require(balances[msg.sender] >= value, "Insuff Balance");
        balances[msg.sender] -= value;
        balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint value) public override returns(bool) {
        
        require(balances[msg.sender] >= value && allowed[from][msg.sender] >= value, "Insuff Allowance");
        allowed[from][msg.sender] -= value;
        balances[msg.sender] -= value;
        balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint value) public override returns(bool) {
        
        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function allowance(address owner, address spender) public view override returns(uint) {
        return allowed[owner][spender];
    }
    
    function balanceOf(address owner) public view override returns(uint) {
        return balances[owner];
    }
}

contract ICO {
    struct Sale {
        address investor;
        uint quantity;
    }
    Sale[] public sales;
    mapping(address => bool) public investors;
    address public token;
    address public admin;
    uint public end;
    uint public price;
    uint public availableTokens;
    uint public tokensSold;
    uint public minPurchase;
    uint public maxPurchase;
    bool public released = true;
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint _totalSupply) {
        token = address(new ERC20Token(
            _name,
            _symbol,
            _decimals,
            _totalSupply
        ));
        admin = msg.sender;
    }
    
    /*
     * @dev Only admin can start the ICO
     * @param duration time period for the ico
     * @param _price price of the single token
     * @param _availableTokens Tokens available for the current ICO
     * @param _minPurchase Minimum amount of tokens investors have to buy
     * @param _maxPurchase Maximum amount of tokens investors can buy 
     */
    function start(
        uint duration,
        uint _price,
        uint _availableTokens,
        uint _minPurchase,
        uint _maxPurchase)
        external onlyOwner() icoNotActive() tokensReleased(){
        require(duration > 0, "Invalid duration");
        require(released == true, "last ICO Tokens not Released");
        uint totalSupply = ERC20Token(token).totalSupply();
        require(_availableTokens > 0 && _availableTokens <= totalSupply, "totalSupply exceded");
        require(_minPurchase > 0, "minPurchase error");
        require(_maxPurchase > _minPurchase && _maxPurchase <= _availableTokens, "maxPurchase error");
        end = duration + block.timestamp; 
        price = _price;
        availableTokens = _availableTokens;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        released = false;
    }
    
    // @dev only whitelisted investors can buy the tokens
    function whitelist(address investor) external onlyOwner() {
        investors[investor] = true;    
    }
    
    function buy() external payable onlyInvestors() icoActive() {

        uint quantity = msg.value*price;
        require(quantity <= availableTokens - tokensSold, "Not enough tokens left for sale");
        require(quantity >= minPurchase && quantity <= maxPurchase, "invalid Range");
        tokensSold += quantity;
        sales.push(Sale(
            msg.sender,
            quantity
        ));
    }
    
    /* @dev releases the tokens back to the investors after the ico has been ended
     * @require only Owner can release the tokens
     */
    function release() external onlyOwner() icoEnded() tokensNotReleased() {

        released = true;
        availableTokens = 0;
        tokensSold = 0;
        end = 0;
        ERC20Token tokenInstance = ERC20Token(token);
        for(uint i = 0; i < sales.length; i++) {
            Sale storage sale = sales[i];
            tokenInstance.transfer(sale.investor, sale.quantity);
        }
    }
    
    /*
     * @dev Transfers the collected amount to the specified address
     * @param to address of the recepient
     * @param amount Amount that is being transferred
     */
    function withdraw( address payable to, uint amount) external onlyOwner() icoNotActive() tokensReleased() {
        require( to != address(0), "Invalid Address");
        require( amount <= contractBalance(), "Insuff Balance"); 
        to.transfer(amount);    
    }

    /// @dev checks the balance of the contract
    function contractBalance() public view returns(uint) {
        return address(this).balance;
    }
    
    /// @dev modifier to check if the ICO is active
    modifier icoActive() {
        require(end > 0 && block.timestamp < end && availableTokens > 0, "ICO must be active");
        _;
    }
    
    /// @dev modifier to check if the ICO is inactive
    modifier icoNotActive() {
        require(end == 0, "ICO is active");
        _;
    }
    
    /// @dev modifier to check if the ICO is ended
    modifier icoEnded() {
        require(end > 0 && (block.timestamp >= end || availableTokens == 0), "ICO must have ended");
        _;
    }
    
    /// @dev modifier to check that tokens are not released yet
    modifier tokensNotReleased() {
        require(released == false, "Tokens released");
        _;
    }
    
    /// @dev modifier to check that tokens are released
    modifier tokensReleased() {
        require(released == true, "Tokens NOT released");
        _;
    }
    
    /// @dev modifier to check that only whitelisted investors can buy from the ICO
    modifier onlyInvestors() {
        require(investors[msg.sender] == true, "only investors");
        _;
    }
    
    /// @dev modifier to check only Owner can call a particular function
    modifier onlyOwner() {
        require(msg.sender == admin, "only admin");
        _;
    }
    
}
