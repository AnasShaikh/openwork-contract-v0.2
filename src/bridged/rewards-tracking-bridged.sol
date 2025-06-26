// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, MessagingFee, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IJobContract {
    function getJob(uint256 jobId) external view returns (
        uint256 id,
        address jobGiver,
        address[] memory applicants,
        string memory jobDetailHash,
        bool isOpen,
        string[] memory workSubmissions,
        uint256 totalPaid,
        uint256 currentLockedAmount,
        uint256 currentMilestone,
        address selectedApplicant,
        uint256 selectedApplicationId
    );
    
    function getProfile(address user) external view returns (
        address userAddress,
        string memory ipfsHash,
        address referrerAddress,
        uint256 rating,
        string[] memory portfolioHashes
    );
}

interface IMainDAO {
    function addOrUpdateEarner(
        address earnerAddress, 
        uint256 balance, 
        uint256 governanceActions, 
        uint256 cumulativeEarnings,
        uint256 totalPlatformPayments
    ) external;
}

contract RewardsTrackingContract is OApp, ReentrancyGuard {
    IJobContract public jobContract;
    IMainDAO public mainDAO; // Keep for backward compatibility/fallback
    
    // Reward bands structure
    struct RewardBand {
        uint256 minAmount;      // Minimum cumulative amount for this band
        uint256 maxAmount;      // Maximum cumulative amount for this band
        uint256 owPerDollar;    // OW tokens per USDT (scaled by 1e18)
    }
    
    // User cumulative tracking
    mapping(address => uint256) public userCumulativeEarnings;
    mapping(address => uint256) public userTotalOWTokens;
    
    // Job tracking
    mapping(uint256 => bool) public jobProcessed;
    mapping(uint256 => uint256) public jobTotalPaid;
    uint256 public currentTotalPlatformPayments;
    
    // Reward bands array
    RewardBand[] public rewardBands;
    
    // LayerZero configuration
    uint32 public destinationEid;
    mapping(bytes32 => bool) public sentMessages;
    bool public useLayerZero = true; // Toggle for using LayerZero vs direct calls
    
    // Events
    event RewardsUpdated(
        uint256 indexed jobId, 
        uint256 paidAmountUSDT, 
        address indexed jobGiver, 
        address indexed jobTaker,
        uint256 jobGiverTokens,
        uint256 jobTakerTokens
    );
    
    event TokensEarned(
        address indexed user, 
        uint256 tokensEarned, 
        uint256 newCumulativeEarnings,
        uint256 newTotalTokens
    );
    
    event MainDAOUpdated(address indexed newMainDAO);
    event EarnerUpdateFailed(address indexed earner, string reason);
    event CrossChainMessageSent(bytes32 indexed messageId, string messageType, address indexed earner);
    event MessageReceived(uint32 indexed srcEid, bytes32 indexed guid, string messageType);
    
    constructor(
        address _owner,
        address _endpoint
    ) OApp(_endpoint, _owner) Ownable(msg.sender) {
        _initializeRewardBands();
        transferOwnership(_owner);
    }
    
    function setDestinationEid(uint32 _destinationEid) external onlyOwner {
        destinationEid = _destinationEid;
    }
    
    function setUseLayerZero(bool _useLayerZero) external onlyOwner {
        useLayerZero = _useLayerZero;
    }
    
    function setJobContract(address _jobContract) external onlyOwner {
        jobContract = IJobContract(_jobContract);
    }
    
    function setMainDAO(address _mainDAO) external onlyOwner {
        mainDAO = IMainDAO(_mainDAO);
        emit MainDAOUpdated(_mainDAO);
    }
    
    function _initializeRewardBands() private {
        // Initialize all reward bands based on the provided table
        rewardBands.push(RewardBand(0, 500 * 1e6, 100000 * 1e18)); // $0 - $500: 100,000 OW per $
        rewardBands.push(RewardBand(500 * 1e6, 1000 * 1e6, 50000 * 1e18)); // $500 - $1,000: 50,000 OW per $
        rewardBands.push(RewardBand(1000 * 1e6, 2000 * 1e6, 25000 * 1e18)); // $1,000 - $2,000: 25,000 OW per $
        rewardBands.push(RewardBand(2000 * 1e6, 4000 * 1e6, 12500 * 1e18)); // $2,000 - $4,000: 12,500 OW per $
        rewardBands.push(RewardBand(4000 * 1e6, 8000 * 1e6, 6250 * 1e18)); // $4,000 - $8,000: 6,250 OW per $
        rewardBands.push(RewardBand(8000 * 1e6, 16000 * 1e6, 3125 * 1e18)); // $8,000 - $16,000: 3,125 OW per $
        rewardBands.push(RewardBand(16000 * 1e6, 32000 * 1e6, 1562 * 1e18)); // $16,000 - $32,000: 1,562 OW per $
        rewardBands.push(RewardBand(32000 * 1e6, 64000 * 1e6, 781 * 1e18)); // $32,000 - $64,000: 781 OW per $
        rewardBands.push(RewardBand(64000 * 1e6, 128000 * 1e6, 391 * 1e18)); // $64,000 - $128,000: 391 OW per $
        rewardBands.push(RewardBand(128000 * 1e6, 256000 * 1e6, 195 * 1e18)); // $128,000 - $256,000: 195 OW per $
        rewardBands.push(RewardBand(256000 * 1e6, 512000 * 1e6, 98 * 1e18)); // $256,000 - $512,000: 98 OW per $
        rewardBands.push(RewardBand(512000 * 1e6, 1024000 * 1e6, 49 * 1e18)); // $512,000 - $1.024M: 49 OW per $
        rewardBands.push(RewardBand(1024000 * 1e6, 2048000 * 1e6, 24 * 1e18)); // $1.024M - $2.048M: 24 OW per $
        rewardBands.push(RewardBand(2048000 * 1e6, 4096000 * 1e6, 12 * 1e18)); // $2.048M - $4.096M: 12 OW per $
        rewardBands.push(RewardBand(4096000 * 1e6, 8192000 * 1e6, 6 * 1e18)); // $4.096M - $8.192M: 6 OW per $
        rewardBands.push(RewardBand(8192000 * 1e6, 16384000 * 1e6, 3 * 1e18)); // $8.192M - $16.384M: 3 OW per $
        rewardBands.push(RewardBand(16384000 * 1e6, 32768000 * 1e6, 15 * 1e17)); // $16.384M - $32.768M: 1.5 OW per $
        rewardBands.push(RewardBand(32768000 * 1e6, 65536000 * 1e6, 75 * 1e16)); // $32.768M - $65.536M: 0.75 OW per $
        rewardBands.push(RewardBand(65536000 * 1e6, 131072000 * 1e6, 38 * 1e16)); // $65.536M - $131.072M: 0.38 OW per $
        rewardBands.push(RewardBand(131072000 * 1e6, type(uint256).max, 19 * 1e16)); // $131.072M+: 0.19 OW per $
    }
    
    function updateRewards(uint256 jobId, uint256 paidAmountUSDT, uint256 totalPlatformPayments) external nonReentrant {
        require(address(jobContract) != address(0), "Job contract not set");
        require(msg.sender == address(jobContract), "Only job contract can call this");
        require(paidAmountUSDT > 0, "Paid amount must be greater than 0");
        
        // Store the platform total
        currentTotalPlatformPayments = totalPlatformPayments;
        
        // Get job details
        (
            ,
            address jobGiver,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            address selectedApplicant,
        ) = jobContract.getJob(jobId);
        
        require(jobGiver != address(0), "Invalid job giver");
        require(selectedApplicant != address(0), "No selected applicant");
        
        // Update job total paid tracking
        jobTotalPaid[jobId] += paidAmountUSDT;
        
        // Get referrers
        address jobGiverReferrer = getReferrer(jobGiver);
        address jobTakerReferrer = getReferrer(selectedApplicant);
        
        // Calculate reward distribution
        uint256 jobGiverAmount = paidAmountUSDT;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = paidAmountUSDT / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != selectedApplicant && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = paidAmountUSDT / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Calculate and update rewards for job giver (after deducting referral amounts)
        uint256 jobGiverTokens = calculateAndUpdateTokens(jobGiver, jobGiverAmount);
        
        // Update rewards for referrers
        uint256 jobGiverReferrerTokens = 0;
        uint256 jobTakerReferrerTokens = 0;
        
        if (jobGiverReferrerAmount > 0) {
            jobGiverReferrerTokens = calculateAndUpdateTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            jobTakerReferrerTokens = calculateAndUpdateTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        
        // Update main DAO with earner information (using LayerZero if enabled)
        _updateMainDAOEarners(jobGiver, jobGiverReferrer, jobTakerReferrer, currentTotalPlatformPayments);
        
        emit RewardsUpdated(jobId, paidAmountUSDT, jobGiver, selectedApplicant, jobGiverTokens, 0); // Job taker gets 0 tokens
    }
    
    function updateRewardsWithOptions(
        uint256 jobId, 
        uint256 paidAmountUSDT, 
        uint256 totalPlatformPayments,
        bytes calldata _options
    ) external payable nonReentrant {
        require(address(jobContract) != address(0), "Job contract not set");
        require(msg.sender == address(jobContract), "Only job contract can call this");
        require(paidAmountUSDT > 0, "Paid amount must be greater than 0");
        require(useLayerZero, "LayerZero not enabled");
        
        // Store the platform total
        currentTotalPlatformPayments = totalPlatformPayments;
        
        // Get job details
        (
            ,
            address jobGiver,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            address selectedApplicant,
        ) = jobContract.getJob(jobId);
        
        require(jobGiver != address(0), "Invalid job giver");
        require(selectedApplicant != address(0), "No selected applicant");
        
        // Update job total paid tracking
        jobTotalPaid[jobId] += paidAmountUSDT;
        
        // Get referrers
        address jobGiverReferrer = getReferrer(jobGiver);
        address jobTakerReferrer = getReferrer(selectedApplicant);
        
        // Calculate reward distribution
        uint256 jobGiverAmount = paidAmountUSDT;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = paidAmountUSDT / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != selectedApplicant && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = paidAmountUSDT / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Calculate and update rewards for job giver (after deducting referral amounts)
        uint256 jobGiverTokens = calculateAndUpdateTokens(jobGiver, jobGiverAmount);
        
        // Update rewards for referrers
        uint256 jobGiverReferrerTokens = 0;
        uint256 jobTakerReferrerTokens = 0;
        
        if (jobGiverReferrerAmount > 0) {
            jobGiverReferrerTokens = calculateAndUpdateTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            jobTakerReferrerTokens = calculateAndUpdateTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        
        // Update main DAO with earner information using LayerZero with options
        _updateMainDAOEarnersWithOptions(jobGiver, jobGiverReferrer, jobTakerReferrer, currentTotalPlatformPayments, _options);
        
        emit RewardsUpdated(jobId, paidAmountUSDT, jobGiver, selectedApplicant, jobGiverTokens, 0); // Job taker gets 0 tokens
    }
    
    function calculateAndUpdateTokens(address user, uint256 amountUSDT) private returns (uint256) {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + amountUSDT;
        
        // Calculate tokens based on progressive bands
        uint256 tokensToAward = calculateTokensForRange(currentCumulative, newCumulative);
        
        // Update user's cumulative earnings and total tokens
        userCumulativeEarnings[user] = newCumulative;
        userTotalOWTokens[user] += tokensToAward;
        
        emit TokensEarned(user, tokensToAward, newCumulative, userTotalOWTokens[user]);
        
        return tokensToAward;
    }
    
    function _updateMainDAOEarners(address jobGiver, address jobGiverReferrer, address jobTakerReferrer, uint256 platformTotal) private {
        // Update job giver in main DAO
        _updateEarnerInMainDAO(jobGiver, platformTotal);
        
        // Update referrers in main DAO if they exist and are different
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            _updateEarnerInMainDAO(jobGiverReferrer, platformTotal);
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobGiver && jobTakerReferrer != jobGiverReferrer) {
            _updateEarnerInMainDAO(jobTakerReferrer, platformTotal);
        }
    }
    
    function _updateMainDAOEarnersWithOptions(address jobGiver, address jobGiverReferrer, address jobTakerReferrer, uint256 platformTotal, bytes calldata _options) private {
        // Update job giver in main DAO
        _updateEarnerInMainDAOWithOptions(jobGiver, platformTotal, _options);
        
        // Update referrers in main DAO if they exist and are different
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            _updateEarnerInMainDAOWithOptions(jobGiverReferrer, platformTotal, _options);
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobGiver && jobTakerReferrer != jobGiverReferrer) {
            _updateEarnerInMainDAOWithOptions(jobTakerReferrer, platformTotal, _options);
        }
    }
    
    function _updateEarnerInMainDAO(address earner, uint256 platformTotal) private {
        if (useLayerZero) {
            // Use LayerZero with default options
            _updateEarnerInMainDAOWithDefaultOptions(earner, platformTotal);
        } else {
            // Use direct call as fallback
            _updateEarnerDirectCall(earner, platformTotal);
        }
    }
    
    function _updateEarnerInMainDAOWithDefaultOptions(address earner, uint256 platformTotal) private {
        bytes memory defaultOptions = hex"0003010011010000000000000000000000000000ea60";
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "UPDATE_EARNER",
            earner,
            userTotalOWTokens[earner],
            uint256(0), // governance actions - keeping current value, main DAO will handle this
            userCumulativeEarnings[earner],
            platformTotal
        );
        
        try this._lzSendUpdateEarner{value: address(this).balance}(payload, defaultOptions, earner) {
            // Success handled in _lzSendUpdateEarner
        } catch {
            // Fallback to direct call if LayerZero fails
            _updateEarnerDirectCall(earner, platformTotal);
        }
    }
    
    function _updateEarnerInMainDAOWithOptions(address earner, uint256 platformTotal, bytes calldata _options) private {
        if (!useLayerZero) {
            _updateEarnerDirectCall(earner, platformTotal);
            return;
        }
        
        // Send cross-chain message
        bytes memory payload = abi.encode(
            "UPDATE_EARNER",
            earner,
            userTotalOWTokens[earner],
            uint256(0), // governance actions - keeping current value, main DAO will handle this
            userCumulativeEarnings[earner],
            platformTotal
        );
        
        try this._lzSendUpdateEarner{value: address(this).balance}(payload, _options, earner) {
            // Success handled in _lzSendUpdateEarner
        } catch {
            // Fallback to direct call if LayerZero fails
            _updateEarnerDirectCall(earner, platformTotal);
        }
    }
    
    function _lzSendUpdateEarner(bytes memory payload, bytes memory _options, address earner) external payable {
        require(msg.sender == address(this), "Internal function only");
        
        MessagingReceipt memory receipt = _lzSend(
            destinationEid,
            payload,
            _options,
            MessagingFee(msg.value, 0),
            payable(address(this))
        );
        
        emit CrossChainMessageSent(receipt.guid, "UPDATE_EARNER", earner);
    }
    
    function _updateEarnerDirectCall(address earner, uint256 platformTotal) private {
        if (address(mainDAO) == address(0)) return;
        
        try mainDAO.addOrUpdateEarner(
            earner,
            userTotalOWTokens[earner],
            0, // governance actions - keeping current value, main DAO will handle this
            userCumulativeEarnings[earner],
            platformTotal
        ) {
            // Success - no event needed as main DAO will emit
        } catch Error(string memory reason) {
            emit EarnerUpdateFailed(earner, reason);
        } catch {
            emit EarnerUpdateFailed(earner, "Unknown error");
        }
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
    function quoteUpdateEarner(
        address earner,
        uint256 platformTotal,
        bytes calldata _options
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(
            "UPDATE_EARNER",
            earner,
            userTotalOWTokens[earner],
            uint256(0),
            userCumulativeEarnings[earner],
            platformTotal
        );
        MessagingFee memory fee = _quote(destinationEid, payload, _options, false);
        return fee.nativeFee;
    }
    
    // Legacy function for backward compatibility (for tests and old calls)
    function updateRewardsLegacy(uint256 jobId, uint256 paidAmountUSDT) external {
        require(address(jobContract) != address(0), "Job contract not set");
        require(msg.sender == address(jobContract), "Only job contract can call this");
        require(paidAmountUSDT > 0, "Paid amount must be greater than 0");
        
        // Calculate new platform total
        uint256 newPlatformTotal = currentTotalPlatformPayments + paidAmountUSDT;
        
        // Store the platform total
        currentTotalPlatformPayments = newPlatformTotal;
        
        // Get job details
        (
            ,
            address jobGiver,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            address selectedApplicant,
        ) = jobContract.getJob(jobId);
        
        require(jobGiver != address(0), "Invalid job giver");
        require(selectedApplicant != address(0), "No selected applicant");
        
        // Update job total paid tracking
        jobTotalPaid[jobId] += paidAmountUSDT;
        
        // Get referrers
        address jobGiverReferrer = getReferrer(jobGiver);
        address jobTakerReferrer = getReferrer(selectedApplicant);
        
        // Calculate reward distribution
        uint256 jobGiverAmount = paidAmountUSDT;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = paidAmountUSDT / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != selectedApplicant && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = paidAmountUSDT / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Calculate and update rewards for job giver (after deducting referral amounts)
        uint256 jobGiverTokens = calculateAndUpdateTokens(jobGiver, jobGiverAmount);
        
        // Update rewards for referrers
        uint256 jobGiverReferrerTokens = 0;
        uint256 jobTakerReferrerTokens = 0;
        
        if (jobGiverReferrerAmount > 0) {
            jobGiverReferrerTokens = calculateAndUpdateTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            jobTakerReferrerTokens = calculateAndUpdateTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        
        // Update main DAO with earner information
        _updateMainDAOEarners(jobGiver, jobGiverReferrer, jobTakerReferrer, newPlatformTotal);
        
        emit RewardsUpdated(jobId, paidAmountUSDT, jobGiver, selectedApplicant, jobGiverTokens, 0); // Job taker gets 0 tokens
    }
    
    function calculateTokensForRange(uint256 fromAmount, uint256 toAmount) public view returns (uint256) {
        if (fromAmount >= toAmount) {
            return 0;
        }
        
        uint256 totalTokens = 0;
        uint256 currentAmount = fromAmount;
        
        for (uint256 i = 0; i < rewardBands.length && currentAmount < toAmount; i++) {
            RewardBand memory band = rewardBands[i];
            
            // Skip bands that are entirely below our starting point
            if (band.maxAmount <= currentAmount) {
                continue;
            }
            
            // Calculate the overlap with this band
            uint256 bandStart = currentAmount > band.minAmount ? currentAmount : band.minAmount;
            uint256 bandEnd = toAmount < band.maxAmount ? toAmount : band.maxAmount;
            
            if (bandStart < bandEnd) {
                uint256 amountInBand = bandEnd - bandStart;
                uint256 tokensInBand = (amountInBand * band.owPerDollar) / 1e6; // Convert USDT (6 decimals) to tokens
                totalTokens += tokensInBand;
                currentAmount = bandEnd;
            }
        }
        
        return totalTokens;
    }
    
    function getReferrer(address user) public view returns (address) {
        if (address(jobContract) == address(0)) {
            return address(0);
        }
        
        try jobContract.getProfile(user) returns (
            address,
            string memory,
            address referrerAddress,
            uint256,
            string[] memory
        ) {
            return referrerAddress;
        } catch {
            return address(0);
        }
    }
    
    // View functions
    function getUserCumulativeEarnings(address user) external view returns (uint256) {
        return userCumulativeEarnings[user];
    }
    
    function getUserTotalOWTokens(address user) external view returns (uint256) {
        return userTotalOWTokens[user];
    }
    
    function getJobTotalPaid(uint256 jobId) external view returns (uint256) {
        return jobTotalPaid[jobId];
    }
    
    function getRewardBandsCount() external view returns (uint256) {
        return rewardBands.length;
    }
    
    function getRewardBand(uint256 index) external view returns (uint256 minAmount, uint256 maxAmount, uint256 owPerDollar) {
        require(index < rewardBands.length, "Invalid band index");
        RewardBand memory band = rewardBands[index];
        return (band.minAmount, band.maxAmount, band.owPerDollar);
    }
    
    // Calculate tokens for a specific amount without updating state
    function calculateTokensForAmount(address user, uint256 additionalAmount) external view returns (uint256) {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + additionalAmount;
        return calculateTokensForRange(currentCumulative, newCumulative);
    }
    
    // Emergency functions
    function updateUserCumulativeEarnings(address user, uint256 newAmount) external onlyOwner {
        userCumulativeEarnings[user] = newAmount;
    }
    
    function updateUserTotalOWTokens(address user, uint256 newAmount) external onlyOwner {
        userTotalOWTokens[user] = newAmount;
    }
    
    // Manual function to update earner in main DAO (for admin use)
    function manualUpdateEarnerInMainDAO(address earner) external onlyOwner {
        _updateEarnerInMainDAO(earner, currentTotalPlatformPayments);
    }
    
    // Manual function to update earner with custom options
    function manualUpdateEarnerWithOptions(address earner, bytes calldata _options) external payable onlyOwner {
        _updateEarnerInMainDAOWithOptions(earner, currentTotalPlatformPayments, _options);
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