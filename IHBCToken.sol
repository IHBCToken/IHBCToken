pragma solidity ^0.4.21;
contract SafeMath {
	function safeAdd(uint256 a, uint256 b) internal pure returns(uint256)
	{
		uint256 c = a + b;
		assert(c >= a);
		return c;
	}
	function safeSub(uint256 a, uint256 b) internal pure returns(uint256)
	{
		assert(b <= a);
		return a - b;
	}
	function safeMul(uint256 a, uint256 b) internal pure returns(uint256)
	{
		if (a == 0) {
		return 0;
		}
		uint256 c = a * b;
		assert(c / a == b);
		return c;
	}
	function safeDiv(uint256 a, uint256 b) internal pure returns(uint256)
	{
		uint256 c = a / b;
		return c;
	}
}

contract owned {
    address public owner;

    function owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}


contract EIP20Interface {
	/* This is a slight change to the ERC20 base standard.
	function totalSupply() constant returns (uint256 supply);
	is replaced with:
	uint256 public totalSupply;
	This automatically creates a getter function for the totalSupply.
	This is moved to the base contract since public getter functions are not
	currently recognised as an implementation of the matching abstract
	function by the compiler.
	*/
	/// total amount of tokens
	uint256 public totalSupply;
	/// @param _owner The address from which the balance will be retrieved
	/// @return The balance
	function balanceOf(address _owner) public view returns (uint256 balance);
	/// @notice send `_value` token to `_to` from `msg.sender`
	/// @param _to The address of the recipient
	/// @param _value The amount of token to be transferred
	/// @return Whether the transfer was successful or not
	function transfer(address _to, uint256 _value) public returns (bool success);
	/// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
	/// @param _from The address of the sender
	/// @param _to The address of the recipient
	/// @param _value The amount of token to be transferred
	/// @return Whether the transfer was successful or not
	function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
	/// @notice `msg.sender` approves `_spender` to spend `_value` tokens
	/// @param _spender The address of the account able to transfer the tokens
	/// @param _value The amount of tokens to be approved for transfer
	/// @return Whether the approval was successful or not
	function approve(address _spender, uint256 _value) public returns(bool success);
	/// @param _owner The address of the account owning tokens
	/// @param _spender The address of the account able to transfer the tokens
	/// @return Amount of remaining tokens allowed to spent
	function allowance(address _owner, address _spender) public view returns (uint256 remaining);
	// solhint-disable-next-line no-simple-event-func-name
	event Transfer(address indexed _from, address indexed _to, uint256 _value);
	event Approval(address indexed _owner, address indexed _spender,uint256 _value);
}

contract IHBCTOKEN is EIP20Interface,owned,SafeMath{
	//// Constant token specific fields
	string public constant name ="IHBCToken";
	string public constant symbol = "IHBC";
    uint public constant decimals = 18;
    string  public version  = 'v0.1';
    uint public constant initialSupply = 300000000;
    
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowances;
    mapping (address => uint) public jail;

    //whitelist
    mapping (address=>bool) public whitelist;

    uint256 public finaliseTime;

    event AllocateToken(address indexed _from, address indexed _to, uint256 _value);

    function IHBCTOKEN() public {
        totalSupply = initialSupply*10**uint256(decimals);                        //  total supply
        balances[msg.sender] = totalSupply;             // Give the creator all initial tokens
         whitelist[msg.sender]=true;
    }

    modifier notFinalised() {
        require(finaliseTime == 0);
        _;
    }
    function addwhitelist(address _account) onlyOwner public{
        whitelist[_account]=true;
    }

    function subwhitelist(address _account) onlyOwner public{
        whitelist[_account]=false;
    }
    function checkwhitelist (address _account) public view returns(bool state) {
        return whitelist[_account];
    }
    
    //send token
    function allocateToken(address _to, uint256 amount) onlyOwner notFinalised public {
        require(_to != address(0x0) && amount > 0);
        
        balances[_to] = safeAdd(balances[_to], amount);
        jail[_to] = safeAdd(jail[_to], amount);
        balances[msg.sender] = safeSub(balances[msg.sender], amount);
        emit AllocateToken(msg.sender, _to, amount);
    }

    function balanceOf(address _account) public view returns (uint) {
        return balances[_account];
    }

    function _transfer(address _from, address _to, uint _value) internal returns(bool) {
        require(_to != address(0x0)&&_value>0);
        require (canTransfer(_from, _value));
        require(balances[_from] >= _value);
        require(safeAdd(balances[_to],_value) > balances[_to]);

        uint previousBalances = safeAdd(balances[_from],balances[_to]);
        balances[_from] = safeSub(balances[_from],_value);
        balances[_to] = safeAdd(balances[_to],_value);
        emit Transfer(_from, _to, _value);
        assert(safeAdd(balances[_from],balances[_to]) == previousBalances);
        return true;
    }

    //Lock tokens
	function canTransfer(address _from, uint256 _value) internal view returns (bool success) {
        require(finaliseTime != 0||whitelist[msg.sender]);

 		uint256 index;  
 		uint256 lockedtoken;
        index = safeSub(now, finaliseTime) / 15 days;
        index = safeAdd(index,1);
        if(jail[_from]>=2000000&&index<24){
        	require(safeSub(balances[_from], _value) >= jail[_from]);
        	return true;
        }
   		if(index>=20){
   			return true;
   		}
   		lockedtoken=jail[_from]-jail[_from]*index*5/100;
        require(safeSub(balances[_from], _value) >= lockedtoken);
        return true;
    }

    function transfer(address _to, uint256 _value) public returns (bool success){
    	return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    	//require(canTransfer(_from, _value));
        require(_value <= allowances[_from][msg.sender]);
        allowances[_from][msg.sender] = safeSub(allowances[_from][msg.sender],_value);
        return _transfer(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowances[_owner][_spender];
    }
 
    //close the raise
    function setFinaliseTime() onlyOwner public {
        require(finaliseTime == 0);
        finaliseTime = now;
    }

    function() public payable {
        revert();
    }
}
