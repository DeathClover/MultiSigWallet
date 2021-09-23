// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount);
    event Submit(uint indexed txId);
    event Confirm(address indexed owner, uint indexed txId);
    event Revoke(address indexed owner, uint indexed txId);
    event Execute(uint indexed txId);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    // mapping from tx id => owner => bool
    mapping(uint => mapping(address => bool)) public confirmations;
    Transaction[] public transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint _txId) {
        require(!confirmations[_txId][msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid number of required confirmations");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }
    
    receive() external payable {
        emit Deposit(msg.sender , msg.value);
    }
    
    function submit(address _to , uint _value , bytes calldata _data) external onlyOwner {
        uint txId = transactions.length;
        transactions.push(Transaction({to: _to , value: _value, data: _data , executed: false}));
        emit Submit(txId);
    }
    
    function confirm(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) notConfirmed(_txId){
        confirmations[_txId][msg.sender] = true;
        emit Confirm(msg.sender,_txId);
    }
    
    function _getConfirmation(uint _txId) private view returns (uint)  {
        uint count = 0;
        
        for (uint i = 0; i < owners.length; i++){
            if (confirmations[_txId][owners[i]]){
                count += 1;
            }
        }
        return count;
    }
    
    function execute(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        Transaction storage transaction = transactions[_txId];
        require(_getConfirmation(_txId) >= required , "The tx needs more confirmations.");
        transaction.executed = true;
        (bool success , ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success,"tx failed");
        emit Execute(_txId);
        
    }
    
    function revokeConfirmation(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(confirmations[_txId][msg.sender],"not confirmed");
        confirmations[_txId][msg.sender] = false;
        emit Revoke(msg.sender,_txId) ; 
    }
}