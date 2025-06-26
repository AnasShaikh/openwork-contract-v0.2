// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    struct Job {
        uint256 id;
        address jobGiver;
        address[] applicants;
        string jobDetailHash;
        bool isOpen;
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

contract AthenaClientContract {
    IERC20 public immutable usdtToken;
    ISkillOracle public immutable skillOracle;
    ILocalOpenWorkJobContract public jobContract;
    address public owner;
    
    mapping(uint256 => bool) public jobDisputeExists; // Track if dispute exists for a job
    uint256 public minDisputeFee = 50 * 10**6; // 50 USDT (6 decimals)
    
    event DisputeRaised(address indexed caller, uint256 jobId, uint256 feeAmount);
    event SkillVerificationSubmitted(address indexed caller, string targetOracleName, uint256 feeAmount);
    event AthenaAsked(address indexed caller, string targetOracle, uint256 feeAmount);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event JobContractSet(address indexed jobContract);
    event MinDisputeFeeSet(uint256 newMinFee);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor(address _usdtToken, address _skillOracle) {
        usdtToken = IERC20(_usdtToken);
        skillOracle = ISkillOracle(_skillOracle);
        owner = msg.sender;
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
        uint256 _feeAmount
    ) external {
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
        if (!isInvolved && job.isOpen) {
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
        
        // Call the SkillOracle contract
        skillOracle.raiseDispute(_jobId, _disputeHash, _oracleName, _feeAmount);
        
        emit DisputeRaised(msg.sender, _jobId, _feeAmount);
    }
    
    function submitSkillVerification(
        string memory _applicationHash,
        uint256 _feeAmount,
        string memory _targetOracleName
    ) external {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        
        // Transfer USDT from caller to this contract
        require(
            usdtToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDT transfer failed"
        );
        
        // Call the SkillOracle contract
        skillOracle.submitSkillVerification(_applicationHash, _feeAmount, _targetOracleName);
        
        emit SkillVerificationSubmitted(msg.sender, _targetOracleName, _feeAmount);
    }
    
    function askAthena(
        string memory _description,
        string memory _hash,
        string memory _targetOracle,
        uint256 _feeAmount
    ) external {
        require(_feeAmount > 0, "Fee amount must be greater than 0");
        
        // Convert fee amount to string for the SkillOracle call
        string memory feeString = uint2str(_feeAmount);
        
        // Transfer USDT from caller to this contract
        require(
            usdtToken.transferFrom(msg.sender, address(this), _feeAmount),
            "USDT transfer failed"
        );
        
        // Call the SkillOracle contract
        skillOracle.askAthena(_description, _hash, _targetOracle, feeString);
        
        emit AthenaAsked(msg.sender, _targetOracle, _feeAmount);
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
        require(usdtToken.transfer(owner, _amount), "Transfer failed");
        
        emit FeesWithdrawn(owner, _amount);
    }
    
    // Function to get contract's USDT balance
    function getContractBalance() external view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }
    
    // Function to transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
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
        if (job.isOpen) {
            for (uint i = 0; i < job.applicants.length; i++) {
                if (job.applicants[i] == _caller) {
                    return true;
                }
            }
        }
        
        return false;
    }
}