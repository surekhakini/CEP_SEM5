
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PharmaShield {
    address public owner;

    mapping(address => bool) public authorizedManufacturers;
    mapping(address => bool) public authorizedParticipants;

    struct MedicineBatch {
        string batchId;
        string medicineName;
        string batchNumber;
        uint256 expiryDate;
        uint256 quantity;
        string sealId;
    }

    struct TransferRecord {
        address sender;
        address receiver;
        uint256 quantity;
        uint256 timestamp;
        string previousSealId;
        string newSealId;
    }

    struct InspectionRecord {
        address inspector;
        uint256 timestamp;
        string notes;
        string previousSealId;
        string newSealId;
    }

    mapping(string => MedicineBatch) private batches;
    mapping(string => address) public currentHolder;
    mapping(string => TransferRecord[]) private transferHistory;
    mapping(string => InspectionRecord[]) private inspectionHistory;

    event ManufacturerAuthorizationChanged(
        address indexed account,
        bool authorized
    );

    event ParticipantAuthorizationChanged(
        address indexed account,
        bool authorized
    );

    event BatchRegistered(
        string indexed batchId,
        address indexed manufacturer,
        uint256 quantity
    );

    event BatchTransferred(
        string indexed batchId,
        address indexed sender,
        address indexed receiver,
        uint256 quantity,
        string previousSealId,
        string newSealId,
        uint256 timestamp
    );

    event BatchInspected(
        string indexed batchId,
        address indexed inspector,
        string notes,
        string previousSealId,
        string newSealId,
        uint256 timestamp
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyAuthorizedManufacturer() {
        require(
            authorizedManufacturers[msg.sender],
            "Not an authorized manufacturer"
        );
        _;
    }

    modifier onlyAuthorizedParticipant() {
        require(
            authorizedParticipants[msg.sender],
            "Not an authorized participant"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedManufacturers[msg.sender] = true;
        authorizedParticipants[msg.sender] = true;

        emit ManufacturerAuthorizationChanged(msg.sender, true);
        emit ParticipantAuthorizationChanged(msg.sender, true);
    }

    function authorizeManufacturer(address account) external onlyOwner {
        require(account != address(0), "Invalid address");

        authorizedManufacturers[account] = true;
        emit ManufacturerAuthorizationChanged(account, true);
    }

    function revokeManufacturer(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(account != owner, "Cannot revoke owner");

        authorizedManufacturers[account] = false;
        emit ManufacturerAuthorizationChanged(account, false);
    }

    function authorizeParticipant(address account) external onlyOwner {
        require(account != address(0), "Invalid address");

        authorizedParticipants[account] = true;
        emit ParticipantAuthorizationChanged(account, true);
    }

    function revokeParticipant(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(account != owner, "Cannot revoke owner");

        authorizedParticipants[account] = false;
        emit ParticipantAuthorizationChanged(account, false);
    }

    function registerBatch(
        string calldata batchId,
        string calldata medicineName,
        string calldata batchNumber,
        uint256 expiryDate,
        uint256 quantity,
        string calldata sealId
    ) external onlyAuthorizedManufacturer {
        require(bytes(batchId).length > 0, "Batch ID required");
        require(bytes(medicineName).length > 0, "Medicine name required");
        require(bytes(batchNumber).length > 0, "Batch number required");
        require(expiryDate > block.timestamp, "Expiry must be in future");
        require(quantity > 0, "Quantity must be positive");
        require(bytes(sealId).length > 0, "Seal ID required");
        require(
            bytes(batches[batchId].batchId).length == 0,
            "Batch already registered"
        );

        batches[batchId] = MedicineBatch({
            batchId: batchId,
            medicineName: medicineName,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            quantity: quantity,
            sealId: sealId
        });

        currentHolder[batchId] = msg.sender;

        emit BatchRegistered(batchId, msg.sender, quantity);
    }

    function transferBatch(
        string calldata batchId,
        address receiver,
        string calldata newSealId
    ) external onlyAuthorizedParticipant {
        _requireBatchExists(batchId);

        require(
            currentHolder[batchId] == msg.sender,
            "Only current holder can transfer"
        );
        require(receiver != address(0), "Invalid receiver");
        require(receiver != msg.sender, "Cannot transfer to yourself");
        require(
            authorizedParticipants[receiver],
            "Receiver is not authorized"
        );
        require(bytes(newSealId).length > 0, "New seal ID required");

        MedicineBatch storage batch = batches[batchId];

        address previousHolder = currentHolder[batchId];
        string memory previousSealId = batch.sealId;
        uint256 batchQuantity = batch.quantity;
        uint256 timestamp = block.timestamp;

        transferHistory[batchId].push(
            TransferRecord({
                sender: previousHolder,
                receiver: receiver,
                quantity: batchQuantity,
                timestamp: timestamp,
                previousSealId: previousSealId,
                newSealId: newSealId
            })
        );

        currentHolder[batchId] = receiver;
        batch.sealId = newSealId;

        emit BatchTransferred(
            batchId,
            previousHolder,
            receiver,
            batchQuantity,
            previousSealId,
            newSealId,
            timestamp
        );
    }

    function inspectBatch(
        string calldata batchId,
        string calldata notes,
        string calldata newSealId
    ) external onlyAuthorizedParticipant {
        _requireBatchExists(batchId);

        require(
            currentHolder[batchId] == msg.sender,
            "Only current holder can inspect"
        );
        require(bytes(notes).length > 0, "Inspection notes required");
        require(bytes(newSealId).length > 0, "New seal ID required");

        MedicineBatch storage batch = batches[batchId];

        string memory previousSealId = batch.sealId;
        uint256 timestamp = block.timestamp;

        inspectionHistory[batchId].push(
            InspectionRecord({
                inspector: msg.sender,
                timestamp: timestamp,
                notes: notes,
                previousSealId: previousSealId,
                newSealId: newSealId
            })
        );

        batch.sealId = newSealId;

        emit BatchInspected(
            batchId,
            msg.sender,
            notes,
            previousSealId,
            newSealId,
            timestamp
        );
    }

    function getBatch(string calldata batchId)
        external
        view
        returns (MedicineBatch memory)
    {
        _requireBatchExists(batchId);
        return batches[batchId];
    }

    function getTransferCount(string calldata batchId)
        external
        view
        returns (uint256)
    {
        _requireBatchExists(batchId);
        return transferHistory[batchId].length;
    }

    function getTransferRecord(
        string calldata batchId,
        uint256 index
    ) external view returns (TransferRecord memory) {
        _requireBatchExists(batchId);
        require(
            index < transferHistory[batchId].length,
            "Transfer index out of bounds"
        );
        return transferHistory[batchId][index];
    }

    function getInspectionCount(string calldata batchId)
        external
        view
        returns (uint256)
    {
        _requireBatchExists(batchId);
        return inspectionHistory[batchId].length;
    }

    function getInspectionRecord(
        string calldata batchId,
        uint256 index
    ) external view returns (InspectionRecord memory) {
        _requireBatchExists(batchId);
        require(
            index < inspectionHistory[batchId].length,
            "Inspection index out of bounds"
        );
        return inspectionHistory[batchId][index];
    }

    function getTransferHistory(string calldata batchId)
        external
        view
        returns (TransferRecord[] memory)
    {
        _requireBatchExists(batchId);
        return transferHistory[batchId];
    }

    function getInspectionHistory(string calldata batchId)
        external
        view
        returns (InspectionRecord[] memory)
    {
        _requireBatchExists(batchId);
        return inspectionHistory[batchId];
    }

    function getBatchHistory(string calldata batchId)
        external
        view
        returns (
            MedicineBatch memory batch,
            address holder,
            TransferRecord[] memory transfers,
            InspectionRecord[] memory inspections
        )
    {
        _requireBatchExists(batchId);

        return (
            batches[batchId],
            currentHolder[batchId],
            transferHistory[batchId],
            inspectionHistory[batchId]
        );
    }

    function _requireBatchExists(string calldata batchId) private view {
        require(
            bytes(batches[batchId].batchId).length > 0,
            "Batch does not exist"
        );
    }
}
