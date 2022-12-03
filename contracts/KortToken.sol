// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract KortToken {
    string public name = "KortToken";
    string public symbol = "KRT";
    string public version = "1.0";
    uint256 public totalSupply = 1000000000000000000000000; // 1 million tokens
    uint8 public decimals = 18;
    address payable public owner;

    //tranfer event
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    // The indexed parameters for logged events will allow you to search for these events using the indexed parameters as filters.

    //allowance event
    event Approval(address indexed _owner, address indexed _to, uint256 _value);

    //TransferFrom Event
    event TransferFrom(
        address indexed _from,
        address indexed _to,
        address indexed _sender,
        uint256 _value
    );

    mapping(address => uint256) public balanceOf;

    //allowance
    mapping(address => mapping(address => uint256)) public allowance;

    // pass the constructor args in migration file's deployer
    constructor() {
        owner = payable(msg.sender);
        // allocate initail supply to some address
        balanceOf[msg.sender] = totalSupply;
    }

    //Transfer function
    function transfer(
        address _to,
        uint256 _value,
        address _from
    ) public returns (bool success) {
        require(
            balanceOf[_from] >= _value,
            "sender not have enough amount of tokens"
        );
        // transfer
        balanceOf[_to] += _value;
        balanceOf[_from] -= _value;

        //Transfer event
        emit Transfer(_from, _to, _value);

        //return a boolean
        return true;
    }

    //Delegated transfer

    // approve
    // approve a specific address to use a specific amount of token to send from my account using the transfer from function

    function approve(address _spender, uint256 _value)
        public
        returns (bool success)
    {
        // handel allowance
        allowance[msg.sender][_spender] = _value;

        // approve event
        emit Approval(msg.sender, _spender, _value);

        //return true
        return true;
    }

    //transferFrom
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        // require _from has enough token
        require(
            _value <= balanceOf[_from],
            "value must be less than the balance of from account"
        );
        // require allowance is big enough
        require(
            _value <= allowance[_from][msg.sender],
            "value must be less or equal to the allowance of sender account"
        );
        // change the balance
        balanceOf[_to] += _value;
        balanceOf[_from] -= _value;
        // update the allowance
        allowance[_from][msg.sender] -= _value;
        //Transfer Event
        emit TransferFrom(_from, _to, msg.sender, _value);
        // return a boolean
        return true;
    }

    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}
