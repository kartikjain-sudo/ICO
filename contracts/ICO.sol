// SPDX-License-Identifier: None
pragma solidity ^0.8.0;


interface ERC20Interface {
    function transfer(address to, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function approve(address spender, uint tokens) external returns (bool success);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function totalSupply() external view returns(uint);
    function decimals() external view returns(uint8);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract ERC20Token is ERC20Interface {

    string public name;
    string public symbol;
    uint8 public override decimals;
    uint public override totalSupply;

    mapping(address => uint) internal balances;
    mapping(address => mapping(address => uint)) internal allowed;
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals) {
            name = _name;
            symbol = _symbol;
            decimals = _decimals;
            totalSupply = 100000000 * 10**decimals;
            balances[msg.sender] = totalSupply;
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
    uint8 private decimals = ERC20Token(token).decimals();
    bool public released = true;
    uint256 public rateOne = 100;
    uint256 public rateTwo = 50;
    uint256 public icoOne = 30e6 * (10 ** decimals);
    uint256 public icoTwo = 80e6 * (10 ** decimals);

    enum SALE {PRESALE, SEEDSALE, CROWDSALE}
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals) {
        token = address(new ERC20Token(
            _name,
            _symbol,
            _decimals
        ));
        admin = msg.sender;
    }
    
    /*
     * @dev Only admin can start the ICO
     * @param _duration time period for the ico in days
     * @param _price price of the single token
     */
    function start(
        uint _duration,
        uint _price)
        external onlyOwner() icoNotActive() {
        require(_duration > block.timestamp, "Invalid End Time");
        availableTokens = ERC20Token(token).totalSupply();
        price = _price;
        end = _duration * 24* 60 * 60;
        released = false;
    }
    
    /// @dev only whitelisted investors can buy the tokens
    function whitelist(address investor) external onlyOwner() {
        investors[investor] = true;    
    }


    /// @dev set the price of the token, only Owner can set this
    function setPrice(uint rate) public onlyOwner {
        require(rate != 0, "Invalid Price");
        price = rate;
    }

    /**
     * @dev Receive function if ether is sent to address instead of buyTokens function
     **/
    receive() external payable {
        buy();
    }

    /*
     * @dev calculates the tokens user will get depending on the amount and sale
     * @param amountInWei amount for which user wants to buy tokens
     * @param icoSale enum to check the presale, seedsale or crowdsale
     * 
     * @note this is an internal function
     */
    function calculateTokens(uint256 amountInWei, uint8 icoSale) internal view returns(uint256 calculatedTokens) {
        require(amountInWei > 0, "Invalid Amount");

        if(icoSale == 0)
            calculatedTokens = (amountInWei*(10 ** decimals)/1e18) * rateOne;
        else if(icoSale == 1)
            calculatedTokens = (amountInWei*(10 ** decimals)/1e18) * rateTwo;
        else if(icoSale == 2)
            calculatedTokens = (amountInWei*(10 ** decimals)/1e18) * price;
   }

    /*
     * @dev Calculates extra tokens if limit is exceeded from one of the sale
     * Ex:- there are 100 tokens available in PRESALE and a user buys 200 tokens,
     * then 100 tokens will be calculated from presale and 100 tokens will be 
     * calculated from seedsale.
     * @param amount amount of tokens for which the tokens will be bought
     * @param icoSale enum for presale, seedsale or crowdfund
     *
     * @returns totalTokens amount of tokens that will be given to the user
     * @returns leftWei when user sends more wei than the available tokens, then the 
     *                  extra amount of wei will be transferred back to the user
     */
    function calculateExcessTokens(
      uint256 amount,
      uint8 icoSale
    ) public view returns(uint256 totalTokens, uint256 leftWei) {
        require(amount > 0, "Invalid Params");
        require(icoSale >= 1 && icoSale <= 3, "Invalid Sale");

        uint maxTokens = calculateTokens(amount, icoSale);
        if (tokensSold < icoOne && tokensSold + maxTokens > icoOne) {
            uint tokensFromIcoOne = icoOne - tokensSold;
            uint tokensToWei = tokensFromIcoOne * 1e18 / 10**decimals / rateOne;
            uint leftAmount = amount - tokensToWei;
            uint tokensFromIcoTwo = calculateTokens(leftAmount, uint8(SALE.SEEDSALE));
            totalTokens = tokensFromIcoOne + tokensFromIcoTwo;
            leftWei = 0;
        }
        else if (tokensSold < icoTwo && tokensSold + maxTokens > icoTwo) {
            uint tokensFromIcoTwo = icoTwo - tokensSold;
            uint tokensToWei = tokensFromIcoTwo * 1e18 / 10**decimals / rateTwo;
            uint leftAmount = amount - tokensToWei;
            uint tokensFromIcoThree = calculateTokens(leftAmount, uint8(SALE.CROWDSALE));
            totalTokens = tokensFromIcoTwo + tokensFromIcoThree;
            leftWei = 0;
        }
        else if (tokensSold + maxTokens > ERC20Token(token).totalSupply()) {
            uint tokensFromIcoThree = ERC20Token(token).totalSupply() - tokensSold;
            uint tokensToWei = tokensFromIcoThree * 1e18 / 10**decimals / rateTwo;
            leftWei = amount - tokensToWei;
            totalTokens = tokensFromIcoThree;
        }
    }
    
    /// @dev buy function for users to buy tokens
    function buy() public payable onlyInvestors() icoActive() {

        uint quantity;
        uint leftWei;
        uint value = msg.value;

        if (tokensSold < icoOne) {
            (quantity, leftWei) = calculateExcessTokens(value, uint8(SALE.PRESALE));
        } else if (tokensSold < icoTwo) {
            (quantity, leftWei) = calculateExcessTokens(value, uint8(SALE.SEEDSALE));
        } else {
            (quantity, leftWei) = calculateExcessTokens(value, uint8(SALE.CROWDSALE));
        }
        require(quantity <= availableTokens, "Not enough tokens left for sale");
        tokensSold += quantity;
        availableTokens -= quantity;
        sales.push(Sale(
            msg.sender,
            quantity
        ));
        if (leftWei > 0) payable(msg.sender).transfer(leftWei);
    }
    
    /* @dev releases the tokens back to the investors after the ico has been ended
     * @require only Owner can release the tokens
     */
    function release() external onlyOwner() icoEnded() tokensNotReleased() {

        released = true;
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
