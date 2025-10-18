// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface INativeOpenWorkJobContract {
    function postJob(string memory jobId, address jobGiver, string memory jobDetailHash, string[] memory descriptions, uint256[] memory amounts) external;
    function startJob(address jobGiver, string memory jobId, uint256 applicationId, bool useApplicantMilestones) external;
    function setApplicantChainDomain(string memory jobId, address applicant, uint32 chainDomain) external;
    function getJobApplicationCount(string memory jobId) external view returns (uint256);
    function genesis() external view returns (address);
}

interface IOpenworkGenesis {
    enum JobStatus { Open, InProgress, Completed, Cancelled }
    
    struct MilestonePayment {
        string descriptionHash;
        uint256 amount;
    }
    
    struct Job {
        string id;
        address jobGiver;
        address[] applicants;
        string jobDetailHash;
        JobStatus status;
        string[] workSubmissions;
        uint256 totalPaid;
        uint256 currentMilestone;
        address selectedApplicant;
        uint256 selectedApplicationId;
    }
    
    function getJob(string memory jobId) external view returns (Job memory);
    function getJobApplicationCount(string memory jobId) external view returns (uint256);
    function addJobApplicant(string memory jobId, address applicant) external;
    function setJobApplication(string memory jobId, uint256 applicationId, address applicant, string memory applicationHash, string[] memory descriptions, uint256[] memory amounts, uint32 preferredPaymentChainDomain, address preferredPaymentAddress) external;
}

contract DirectContractManager is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ==================== STATE VARIABLES ====================
    
    INativeOpenWorkJobContract public nowjc;
    address public bridge;
    
    // Counter for generating unique application IDs
    uint256 private directContractCounter;
    
    // ==================== EVENTS ====================
    
    event DirectContractStarted(
        string indexed jobId,
        address indexed jobGiver,
        address indexed jobTaker,
        uint256 applicationId,
        string jobDetailHash
    );
    event DirectContractFailed(
        string indexed jobId,
        string reason,
        uint8 step
    );
    event NOWJCAddressUpdated(address indexed oldNOWJC, address indexed newNOWJC);
    event BridgeUpdated(address indexed oldBridge, address indexed newBridge);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _nowjc,
        address _bridge
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        
        nowjc = INativeOpenWorkJobContract(_nowjc);
        bridge = _bridge;
        directContractCounter = 0;
    }

    function _authorizeUpgrade(address /* newImplementation */) internal view override {
        require(owner() == _msgSender() || bridge == _msgSender(), "Unauthorized");
    }

    function upgradeFromDAO(address newImplementation) external {
        require(msg.sender == bridge, "Only bridge");
        upgradeToAndCall(newImplementation, "");
    }
    
    // ==================== ADMIN FUNCTIONS ====================
    
    function setNOWJC(address _nowjc) external onlyOwner {
        require(_nowjc != address(0), "Invalid NOWJC address");
        address oldNOWJC = address(nowjc);
        nowjc = INativeOpenWorkJobContract(_nowjc);
        emit NOWJCAddressUpdated(oldNOWJC, _nowjc);
    }
    
    function setBridge(address _bridge) external onlyOwner {
        require(_bridge != address(0), "Invalid bridge address");
        address oldBridge = bridge;
        bridge = _bridge;
        emit BridgeUpdated(oldBridge, _bridge);
    }
    
    // ==================== DIRECT CONTRACT FUNCTIONALITY ====================
    
    /**
     * @dev Handle direct contract creation from bridge
     * Option C: postJob + Genesis direct application + setChainDomain + startJob
     * This bypasses NOWJC's applyToJob to avoid cross-chain execution issues
     */
    function handleStartDirectContract(
        address _jobGiver,
        address _jobTaker,
        string memory _jobId,
        string memory _jobDetailHash,
        string[] memory _descriptions,
        uint256[] memory _amounts,
        uint32 _jobTakerChainDomain
    ) external {
        require(msg.sender == bridge, "Only bridge can call");
        require(_jobGiver != address(0), "Invalid job giver");
        require(_jobTaker != address(0), "Invalid job taker");
        require(_descriptions.length > 0, "Must have milestones");
        require(_descriptions.length == _amounts.length, "Length mismatch");
        
        // Step 1: Post the job via NOWJC
        try nowjc.postJob(_jobId, _jobGiver, _jobDetailHash, _descriptions, _amounts) {
            
            // Step 2: Get Genesis contract and store application directly
            address genesisAddress = nowjc.genesis();
            IOpenworkGenesis genesis = IOpenworkGenesis(genesisAddress);
            
            try genesis.addJobApplicant(_jobId, _jobTaker) {
                
                // Step 3: Get next application ID
                uint256 applicationId = genesis.getJobApplicationCount(_jobId) + 1;
                
                // Step 4: Store application in Genesis
                try genesis.setJobApplication(
                    _jobId,
                    applicationId,
                    _jobTaker,
                    "direct-contract-auto-application",
                    _descriptions,
                    _amounts,
                    _jobTakerChainDomain,
                    _jobTaker
                ) {
                    
                    // Step 5: Set chain domain mapping in NOWJC
                    try nowjc.setApplicantChainDomain(_jobId, _jobTaker, _jobTakerChainDomain) {
                        
                        // Step 6: Start the job
                        try nowjc.startJob(_jobGiver, _jobId, applicationId, false) {
                            // Increment counter for tracking
                            directContractCounter++;
                            
                            emit DirectContractStarted(_jobId, _jobGiver, _jobTaker, applicationId, _jobDetailHash);
                        } catch Error(string memory reason) {
                            emit DirectContractFailed(_jobId, reason, 5);
                            revert(string(abi.encodePacked("StartJob failed: ", reason)));
                        } catch {
                            emit DirectContractFailed(_jobId, "StartJob failed with unknown error", 5);
                            revert("StartJob failed with unknown error");
                        }
                    } catch Error(string memory reason) {
                        emit DirectContractFailed(_jobId, reason, 4);
                        revert(string(abi.encodePacked("SetChainDomain failed: ", reason)));
                    } catch {
                        emit DirectContractFailed(_jobId, "SetChainDomain failed with unknown error", 4);
                        revert("SetChainDomain failed with unknown error");
                    }
                } catch Error(string memory reason) {
                    emit DirectContractFailed(_jobId, reason, 3);
                    revert(string(abi.encodePacked("SetJobApplication failed: ", reason)));
                } catch {
                    emit DirectContractFailed(_jobId, "SetJobApplication failed with unknown error", 3);
                    revert("SetJobApplication failed with unknown error");
                }
            } catch Error(string memory reason) {
                emit DirectContractFailed(_jobId, reason, 2);
                revert(string(abi.encodePacked("AddJobApplicant failed: ", reason)));
            } catch {
                emit DirectContractFailed(_jobId, "AddJobApplicant failed with unknown error", 2);
                revert("AddJobApplicant failed with unknown error");
            }
        } catch Error(string memory reason) {
            emit DirectContractFailed(_jobId, reason, 1);
            revert(string(abi.encodePacked("PostJob failed: ", reason)));
        } catch {
            emit DirectContractFailed(_jobId, "PostJob failed with unknown error", 1);
            revert("PostJob failed with unknown error");
        }
    }
    
    // ==================== VIEW FUNCTIONS ====================
    
    function getDirectContractCount() external view returns (uint256) {
        return directContractCounter;
    }
    
    function getNOWJCAddress() external view returns (address) {
        return address(nowjc);
    }
    
    function getBridgeAddress() external view returns (address) {
        return bridge;
    }
    
    function getDirectContractStatus(string memory jobId) external view returns (bool success, string memory reason) {
        try nowjc.genesis() returns (address genesisAddress) {
            IOpenworkGenesis genesis = IOpenworkGenesis(genesisAddress);
            try genesis.getJob(jobId) returns (IOpenworkGenesis.Job memory job) {
                if (bytes(job.id).length == 0) {
                    return (false, "Job does not exist");
                }
                if (job.selectedApplicant == address(0)) {
                    return (false, "No applicant selected - job not started");
                }
                if (job.status != IOpenworkGenesis.JobStatus.InProgress) {
                    return (false, "Job not in progress status");
                }
                return (true, "Direct contract completed successfully");
            } catch {
                return (false, "Failed to query job from Genesis");
            }
        } catch {
            return (false, "Failed to get Genesis contract address");
        }
    }
    
    // ==================== RECOVERY FUNCTIONS ====================
    
    function completeFailedDirectContract(
        string memory jobId,
        address jobTaker,
        uint32 jobTakerChainDomain
    ) external onlyOwner {
        // Try to complete the missing steps using Option C approach
        try nowjc.getJobApplicationCount(jobId) returns (uint256 appCount) {
            if (appCount == 0) {
                // Missing application - add it directly via Genesis
                address genesisAddress = nowjc.genesis();
                IOpenworkGenesis genesis = IOpenworkGenesis(genesisAddress);
                IOpenworkGenesis.Job memory job = genesis.getJob(jobId);
                
                if (job.selectedApplicant == address(0)) {
                    // Create simplified milestone structure for recovery
                    string[] memory descriptions = new string[](1);
                    uint256[] memory amounts = new uint256[](1);
                    descriptions[0] = "Recovery milestone";
                    amounts[0] = 500000;
                    
                    // Use Option C approach for recovery
                    genesis.addJobApplicant(jobId, jobTaker);
                    uint256 applicationId = genesis.getJobApplicationCount(jobId) + 1;
                    genesis.setJobApplication(
                        jobId,
                        applicationId,
                        jobTaker,
                        "direct-contract-auto-application-recovery",
                        descriptions,
                        amounts,
                        jobTakerChainDomain,
                        jobTaker
                    );
                    
                    // Set chain domain in NOWJC
                    nowjc.setApplicantChainDomain(jobId, jobTaker, jobTakerChainDomain);
                    
                    // Start the job
                    nowjc.startJob(job.jobGiver, jobId, applicationId, false);
                }
            }
        } catch {
            revert("Failed to complete recovery");
        }
    }
}
