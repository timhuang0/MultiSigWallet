pragma solidity >=0.4.22 <0.6.0;

contract MultiSigWallet {
    address private _owner;
    mapping(address => uint8) private _owners;

    mapping (uint => Transaction) private _transactions;
    uint[] private _pendingTransactions;

    // auto incrememnting transaction ID
    uint private _transactionIndex;
    // constant: # of signatures needed to sign Transaction
    uint constant MIN_SIGNATURES = 2;

    struct Transaction {
        address source;
        address payable destination;
        uint value;
        //number of validOwners who signed
        uint signatureCount;
        //keeps track of who already signed transaction
        MultiSigData sigData;
    }

    struct MultiSigData {
        // addresses that signed
        address[] signers;
    }

    modifier isOwner() {
        require(msg.sender == _owner);
        _;
    }

    modifier validOwner() {
        require(msg.sender == _owner || _owners[msg.sender] == 1);
        _;
    }

    /// @dev logged events
    event DepositFunds(address source, uint amount);
    /// @dev full sequence of the transaction event logged
    event TransactionCreated(address source, address destination, uint value, uint transactionID);
    event TransactionCompleted(address source, address destination, uint value, uint transactionID);
    /// @dev keeps track of who is signing the transactions
    event TransactionSigned(address by, uint transactionID);


    /// @dev Contract constructor sets initial owners
    constructor() public {
        _owner = msg.sender;
    }

    /// @dev add new owner to have access, enables the ability to create more than one owner to manage the wallet
    function addOwner(address newOwner) isOwner public {
        _owners[newOwner] = 1;
    }

    /// @dev remove suspicious owners
    function removeOwner(address existingOwner) isOwner public {
        _owners[existingOwner] = 0;
    }

    /// @dev Fallback function, which accepts ether when sent to contract
    function () external payable {
        emit DepositFunds(msg.sender, msg.value);
    }

    function withdraw(uint amount) validOwner public {
        transferTo(msg.sender, amount);
    }

    /// @dev Send ether to specific a transaction
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    ///
    /// Start by creating your transaction. Since we defined it as a struct,
    /// we need to define it in a memory context. Update the member attributes.
    ///
    /// note, keep transactionID updated
    function transferTo(address payable destination, uint value) validOwner public {
        require(address(this).balance >= value);

        address[] memory signatures = new address[] (MIN_SIGNATURES);
        signatures[0] = msg.sender;

        MultiSigData memory msd = MultiSigData(
            signatures
        );

        //create the transaction
        Transaction memory t = Transaction (
            address(this),
            destination,
            value,
            1,
            msd
        );

        //add transaction to the data structures
        _transactions[_transactionIndex] = t;
        _pendingTransactions.push(_transactionIndex);

        //log that the transaction was created to a specific address
        emit TransactionCreated(t.source, t.destination, t.value, _transactionIndex);

        _transactionIndex++;
    }

    //returns pending transcations
    function getPendingTransactions() view validOwner public returns (uint[] memory) {
        return _pendingTransactions;
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    /// Sign and Execute transaction.
    function signTransaction(uint transactionId) validOwner public {

        Transaction storage transaction = _transactions[transactionId];

        // Transaction must exist
        require(_transactions[transactionId].value > 0);

        // Creator cannot sign the transaction
        require(transaction.source != msg.sender);

        // Cannot sign a transaction more than once
        for (uint i = 0; i < transaction.signatureCount; i++) {
            require(transaction.sigData.signers[i] != msg.sender);
        }

        // increment signatureCount
        transaction.signatureCount++;

        // log transaction
        emit TransactionSigned(msg.sender, transactionId);

        // check to see if transaction has enough signatures, if true, make the transaction.
        if (transaction.signatureCount >= MIN_SIGNATURES) {

            require(address(this).balance >= transaction.value); //validate transaction
            transaction.destination.transfer(transaction.value);

            //log that the transaction was complete
            emit TransactionCompleted(transaction.source, transaction.destination, transaction.value, transactionId);

            //delete the transaction
            deleteTransaction(transactionId);
        }
    }


    function deleteTransaction(uint transactionId) validOwner public {
        uint8 replace = 0;
        for(uint i = 0; i < _pendingTransactions.length; i++) {
            if (1 == replace) {
                _pendingTransactions[i-1] = _pendingTransactions[i];
            } else if (transactionId == _pendingTransactions[i]) {
                replace = 1;
            }
        }
        delete _pendingTransactions[_pendingTransactions.length - 1];
        _pendingTransactions.length--;
        delete _transactions[transactionId];
    }

    /// @return Returns balance
    function walletBalance() view public returns (uint) {
        return address(this).balance;
    }

}
