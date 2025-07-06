// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, MessagingFee, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ISkillOracle {
    function raiseDispute(uint256 _jobId, string memory _disputeHash, string memory _oracleName, uint256 _fee) external;
    function submitSkillVerification(string memory _applicationHash, uint256 _feeAmount, string memory _targetOracleName) external;
    function askAthena(string memory _description, string memory _hash, string memory _targetOracle, string memory _fees) external;
}

interface ILocalOpenWorkJobContract {
    enum JobStatus {
        Open,
        InProgress,
        Completed,
        Cancelled
    }
    
    struct Job {
        uint256 id;
        address jobGiver;
        address[] applicants;
        string jobDetailHash;
        JobStatus status;
        string[] workSubmissions;
        uint256 totalPaid;
        uint256 currentLockedAmount;
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
        uint256 totalEscrowed;
        uint256 totalReleased;
    }
    
    function getJob(uint256 _jobId) external view returns (Job memory);
}

contract AthenaClientContract is OApp, ReentrancyGuard {
    IERC20 public immutable usdtToken;
    ISkillOracle public immutable skillOracle;
    ILocalOpenWorkJobContract public jobContract;
    
    mapping(uint256 => bool) public jobDisputeExists; // Track if dispute exists for a job
    uint256 public minDisputeFee = 50 * 10**6; // 50 USDT (6 decimals)
    
    // LayerZero configuration
    uint32 public destinationEid;
    mapping(bytes32 => bool) public sentMessages;
    
    event DisputeRaised(address indexed caller, uint256 jobId, uint256 feeAmount);
    event SkillVerificationSubmitted(address indexed caller, string targetOracleName, uint256 feeAmount);
    event AthenaAsked(address indexed caller, string targetOracle, uint256 feeAmount);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event JobContractSet(address indexed jobContract);
    event MinDisputeFeeSet(uint256 newMinFee);
    event CrossChainMessageSent(bytes32 indexed messageId, string messageType, uint256 indexed jobId);
    event MessageReceived(uint32 indexed srcEid, bytes32 indexed guid, string messageType);
    
    constructor(
        address _usdtToken, 
        address _skillOracle,
        address _endpoint,
        address _owner
    ) OApp(_endpoint, _owner) Ownable(msg.sender) {
        usdtToken = IERC20(_usdtToken);
        skillOracle = ISkillOracle(_skillOracle);
        transferOwnership(_owner);
    }
    
    function setDestinationEid(uint32 _destinationEid) external onlyOwner {
        destinationEid = _destinationEid;
    }
    
    function setJobContract(address _jobContract) external onlyOwner {
        require(_jobContract != address(0), "Job contract address cannot be zero");
        jobContract = ILocalOpenWorkJobContract(_jobContract);
        emit JobContractSet(_jobContract);
    }
    
    function setMinDisputeFee(uint256 _minFee) external onlyOwner {
        minDisputeFee = _minFee;
        emit MinDisputeFeeSet(_minFee);
    }
    
    function raiseDispute(
        uint256 _jobId,
        string memory _disputeHash,
        string memory _oracleName,
        uint256 _feeAmount,
        bytes calldata _options
    ) external payable nonReentrant {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        require(address(jobContract) != address(0), "Job contract not set");
        require(!jobDisputeExists[_jobId], "Dispute already exists for this job");
        require(_feeAmount >= minDisputeFee, "Fee below minimum required");
        
        // Get job details and validate caller involvement
        ILocalOpenWorkJobContract.Job memory job = jobContract.getJob(_jobId);
        require(job.id != 0, "Job does not exist");
        
        // Check if caller is involved in the job
        bool isInvolved = false;
        if (msg.sender == job.jobGiver || msg.sender == job.selectedApplicant) {
            isInvolved = true;
        }
        
        // If job is still open, check if caller is an applicant
        if (!isInvolved && job.status == ILocalOpenWorkJobContract.JobStatus.Open) {
            for (uint i = 0; i < job.applicants.length; i++) {
                if (job.applicants[i] == msg.sender) {
                    isInvolved = true;
                    break;
                }
            }
        }
        
        require(isInvolved, "Caller not involved in job");
        
        // Transfer USDT from caller to this contract only after validation
        require(
            usdtToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDT transfer failed"
        );
        
        // Mark dispute as existing for this job
        jobDisputeExists[_jobId] = true;
        
        // Call the SkillOracle contract locally
        skillOracle.raiseDispute(_jobId, _disputeHash, _oracleName, _feeAmount);
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "RAISE_DISPUTE",
            msg.sender,
            _jobId,
            _disputeHash,
            _oracleName,
            _feeAmount
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit DisputeRaised(msg.sender, _jobId, _feeAmount);
        emit CrossChainMessageSent(receipt.guid, "RAISE_DISPUTE", _jobId);
    }
    
    function submitSkillVerification(
        string memory _applicationHash,
        uint256 _feeAmount,
        string memory _targetOracleName,
        bytes calldata _options
    ) external payable nonReentrant {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        
        // Transfer USDT from caller to this contract
        require(
            usdtToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDT transfer failed"
        );
        
        // Call the SkillOracle contract locally
        skillOracle.submitSkillVerification(_applicationHash, _feeAmount, _targetOracleName);
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "SUBMIT_SKILL_VERIFICATION",
            msg.sender,
            _applicationHash,
            _feeAmount,
            _targetOracleName
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit SkillVerificationSubmitted(msg.sender, _targetOracleName, _feeAmount);
        emit CrossChainMessageSent(receipt.guid, "SUBMIT_SKILL_VERIFICATION", 0);
    }
    
    function askAthena(
        string memory _description,
        string memory _hash,
        string memory _targetOracle,
        uint256 _feeAmount,
        bytes calldata _options
    ) external payable nonReentrant {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        
        // Convert fee amount to string for the SkillOracle call
        string memory feeString = uint2str(_feeAmount);
        
        // Transfer USDT from caller to this contract
        require(
            usdtToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDT transfer failed"
        );
        
        // Call the SkillOracle contract locally
        skillOracle.askAthena(_description, _hash, _targetOracle, feeString);
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "ASK_ATHENA",
            msg.sender,
            _description,
            _hash,
            _targetOracle,
            _feeAmount
        );
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );
        
        emit AthenaAsked(msg.sender, _targetOracle, _feeAmount);
        emit CrossChainMessageSent(receipt.guid, "ASK_ATHENA", 0);
    }
    
    // LayerZero receive function
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address _executor,
        bytes calldata _extraData
    ) internal override {
        // Decode the message
        (string memory messageType) = abi.decode(payload, (string));
        
        emit MessageReceived(_origin.srcEid, _guid, messageType);
    }
    
    // Quote functions for gas estimation
    function quoteRaiseDispute(
        uint256 _jobId,
        string memory _disputeHash,
        string memory _oracleName,
        uint256 _feeAmount,
        bytes calldata _options
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(
            "RAISE_DISPUTE",
            msg.sender,
            _jobId,
            _disputeHash,
            _oracleName,
            _feeAmount
        );
        MessagingFee memory fee = _quote(destinationEid, payload, _options, false);
        return fee.nativeFee;
    }
    
    function quoteSubmitSkillVerification(
        string memory _applicationHash,
        uint256 _feeAmount,
        string memory _targetOracleName,
        bytes calldata _options
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(
            "SUBMIT_SKILL_VERIFICATION",
            msg.sender,
            _applicationHash,
            _feeAmount,
            _targetOracleName
        );
        MessagingFee memory fee = _quote(destinationEid, payload, _options, false);
        return fee.nativeFee;
    }
    
    function quoteAskAthena(
        string memory _description,
        string memory _hash,
        string memory _targetOracle,
        uint256 _feeAmount,
        bytes calldata _options
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(
            "ASK_ATHENA",
            msg.sender,
            _description,
            _hash,
            _targetOracle,
            _feeAmount
        );
        MessagingFee memory fee = _quote(destinationEid, payload, _options, false);
        return fee.nativeFee;
    }
    
    // Utility function to convert uint to string
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    // Owner function to withdraw collected fees
    function withdrawFees(uint256 _amount) external onlyOwner {
        require(_amount <= usdtToken.balanceOf(address(this)), "Insufficient contract balance");
        require(usdtToken.transfer(owner(), _amount), "Transfer failed");
        
        emit FeesWithdrawn(owner(), _amount);
    }
    
    // Function to get contract's USDT balance
    function getContractBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }
    
    // Function to check if job exists and caller is involved
    function isCallerInvolvedInJob(uint256 _jobId, address _caller) external view returns (bool) {
        require(address(jobContract) != address(0), "Job contract not set");
        
        ILocalOpenWorkJobContract.Job memory job = jobContract.getJob(_jobId);
        if (job.id == 0) return false;
        
        // Check if caller is job giver or selected applicant
        if (_caller == job.jobGiver || _caller == job.selectedApplicant) {
            return true;
        }
        
        // If job is still open, check if caller is an applicant
        if (job.status == ILocalOpenWorkJobContract.JobStatus.Open) {
            for (uint i = 0; i < job.applicants.length; i++) {
                if (job.applicants[i] == _caller) {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    // Withdraw contract balance (owner only)
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner()).transfer(balance);
    }
    
    // Receive function to accept ETH
    receive() external payable {}
}