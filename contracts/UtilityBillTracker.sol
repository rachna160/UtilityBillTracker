// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title UtilityBillTracker
 * @notice Smart contract for tracking and processing utility bill payments on the blockchain.
 */
contract Project {
    // 1. STATE VARIABLES
    address private immutable i_owner; // The deployed/Utility Company address
    uint private s_billCount;

    // 2. STRUCT: Defines the data structure for a single utility bill
    struct Bill {
        address payable consumer;        // The customer address
        address payable utilityProvider; // The issuer/owner address
        uint amountDue;                 // Amount in Wei
        uint dueDate;                   // Due date as a Unix timestamp
        bool isPaid;
        uint datePaid;                  // Date paid as a Unix timestamp
    }

    // 3. MAPPING: Storage to look up bill details by a unique ID
    mapping(uint => Bill) public idToBill;

    // 4. EVENT: Notifications for off-chain applications
    event BillAdded(uint indexed billID, address indexed consumer, uint amountDue, uint dueDate);
    event BillPaid(uint indexed billID, address indexed consumer, uint amountPaid, uint datePaid);

    // Modifier to restrict functions to the contract owner
    modifier onlyOwner() {
        require(msg.sender == i_owner, "Access: Only the Utility Provider (Owner) can call this.");
        _;
    }

    // Constructor: Sets the deployer as the Utility Provider/Owner
    constructor() {
        i_owner = msg.sender;
    }

    // --- CORE FUNCTIONS ---

    /**
     * @notice Adds a new utility bill to the tracker. Only callable by the Owner.
     * @param _consumer The address of the customer who owes the bill.
     * @param _amountDue The bill amount in Wei.
     * @param _dueDate The Unix timestamp representing the payment due date.
     */
    function addBill(
        address payable _consumer,
        uint _amountDue,
        uint _dueDate
    ) public onlyOwner {
        s_billCount++; // Increment for the new unique ID

        // Create and store the new bill
        idToBill[s_billCount] = Bill({
            consumer: _consumer,
            utilityProvider: payable(msg.sender),
            amountDue: _amountDue,
            dueDate: _dueDate,
            isPaid: false,
            datePaid: 0
        });

        emit BillAdded(s_billCount, _consumer, _amountDue, _dueDate);
    }

    /**
     * @notice Allows a consumer to pay their bill.
     * @param _billID The unique ID of the bill being paid.
     * @dev The function must be 'payable' to accept Ether (msg.value).
     */
    function payBill(uint _billID) public payable {
        // Get a storage reference to the bill
        Bill storage bill = idToBill[_billID];

        // Validation Checks
        require(bill.consumer == msg.sender, "Payment Failed: You are not the consumer for this bill.");
        require(bill.isPaid == false, "Payment Failed: Bill is already paid.");
        require(msg.value >= bill.amountDue, "Payment Failed: Insufficient amount sent.");

        // Update the bill state
        bill.isPaid = true;
        bill.datePaid = block.timestamp;
        
        // Transfer the exact bill amount to the Utility Provider
        (bool success, ) = bill.utilityProvider.call{value: bill.amountDue}("");
        require(success, "Payment Failed: Transfer to provider failed.");
        
        // Refund any overpayment to the consumer (msg.sender)
        if (msg.value > bill.amountDue) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - bill.amountDue}("");
            require(refundSuccess, "Payment Error: Refund failed.");
        }

        emit BillPaid(_billID, msg.sender, bill.amountDue, bill.datePaid);
    }

    /**
     * @notice Checks if a bill is past its due date.
     * @param _billID The unique ID of the bill.
     * @return bool True if the current time is past the due date.
     */
    function isOverdue(uint _billID) public view returns (bool) {
        // Validation check for bill existence
        require(idToBill[_billID].consumer != address(0), "Error: Bill ID does not exist.");

        // Check if the current block time is past the due date
        return block.timestamp > idToBill[_billID].dueDate;
    }
}
