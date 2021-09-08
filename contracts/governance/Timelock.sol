// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract Timelock {

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event ExecuteTransaction(
        bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event QueueTransaction(
        bytes32 indexed txHash, address indexed target, uint value, string signature, bytes data, uint eta);

    uint public constant GRACE_PERIOD = 14 days;
    uint public constant MINIMUM_DELAY = 2 days;
    uint public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    uint public delay;
    bool public admin_initialized;

    mapping (bytes32 => bool) public queuedTransactions;


    constructor(address admin_, uint delay_) {
        require(delay_ >= MINIMUM_DELAY, "delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "delay must not exceed maximum delay.");

        admin = admin_;
        delay = delay_;
        admin_initialized = false;
    }

    receive() external payable { }

    function setDelay(uint delay_) public {
        require(msg.sender == address(this), "setDelay: Call must come from Timelock.");
        require(delay_ >= MINIMUM_DELAY, "setDelay: Delay must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "setDelay: Delay must not exceed maximum delay.");
        delay = delay_;

        emit NewDelay(delay);
    }

    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) public {
        // allows one time setting of admin for deployment purposes
        if (admin_initialized) {
            require(msg.sender == address(this), "setPendingAdmin: Call must come from Timelock.");
        } else {
            require(msg.sender == admin, "setPendingAdmin: First call must come from admin.");
            admin_initialized = true;
        }
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    function queueTransaction(
        address target, 
        uint value, 
        string memory signature, 
        bytes memory data, 
        uint eta
        ) public returns (bytes32 txHash) {
            require(msg.sender == admin, "queueTx: Call must come from admin.");
            require(eta >= getBlockTimestamp()+ delay, "queueTx: Est'd execution block must satisfy delay.");
            bytes32 txnHash = keccak256(abi.encode(target, value, signature, data, eta));
            queuedTransactions[txnHash] = true;
            
            emit QueueTransaction(txnHash, target, value, signature, data, eta);

            return keccak256(abi.encode(target, value, signature, data, eta));
    }

    function cancelTransaction(
        address target, 
        uint value, 
        string memory signature, 
        bytes memory data, 
        uint eta
        ) public {
            require(msg.sender == admin, "cancelTx: Call must come from admin.");
            bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
            queuedTransactions[txHash] = false;

            emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target, 
        uint value, 
        string memory signature,
        bytes memory data, 
        uint eta
        ) public payable returns (bytes memory callData) {
            require(msg.sender == admin, "executeTx: Call must come from admin.");

            bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
            require(queuedTransactions[txHash], "executeTx: Transaction hasn't been queued.");
            require(getBlockTimestamp() >= eta, "executeTx: Transaction hasn't surpassed time lock.");
            require(getBlockTimestamp() <= eta+ GRACE_PERIOD, "executeTx: Transaction is stale.");

            queuedTransactions[txHash] = false;

            emit ExecuteTransaction(txHash, target, value, signature, data, eta);
            if (bytes(signature).length == 0) {
                return data;
            } else {
                return abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
            }

    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}