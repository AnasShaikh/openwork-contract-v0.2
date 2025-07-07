// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { OAppReceiver } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppReceiver.sol";
import { OAppCore } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppCore.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IMainDAO {
    function getEarner(address earnerAddress) external view returns (address, uint256, uint256, uint256);
}

contract RewardsContract is OAppReceiver, ReentrancyGuard {
    IERC20 public openworkToken;
    IMainDAO public mainDAO;
    
    // User referrer mapping
    mapping(address => address) public userReferrers;
    
    // Reward bands structure for job-based rewards
    struct RewardBand {
        uint256 minAmount;      // Minimum cumulative amount for this band
        uint256 maxAmount;      // Maximum cumulative amount for this band
        uint256 owPerDollar;    // OW tokens per USDT (scaled by 1e18)
    }
    
    // Governance reward bands structure
    struct GovernanceRewardBand {
        uint256 minValue;       // Minimum USD value for this band
        uint256 maxValue;       // Maximum USD value for this band
        uint256 rewardPerAction; // OW tokens per governance action (scaled by 1e18)
    }
    
    // User tracking for job-based rewards
    mapping(address => uint256) public userCumulativeEarnings;
    mapping(address => uint256) public userTotalOWTokens;
    
    // Governance rewards tracking
    mapping(address => uint256) public claimedGovernanceRewards;
    mapping(address => uint256) public governanceActionCount;
    
    // Job tracking
    uint256 public currentTotalPlatformPayments;
    
    // Reward bands arrays
    RewardBand[] public rewardBands;
    GovernanceRewardBand[] public governanceRewardBands;
    
    // Authorization
    mapping(address => bool) public authorizedContracts;
    
    // Events
    event ProfileCreated(address indexed user, address indexed referrer);
    event PaymentProcessed(
        address indexed jobGiver, 
        address indexed jobTaker,
        uint256 amount,
        uint256 newPlatformTotal
    );
    
    event TokensEarned(
        address indexed user, 
        uint256 tokensEarned, 
        uint256 newCumulativeEarnings,
        uint256 newTotalTokens
    );
    
    event GovernanceRewardsClaimed(address indexed user, uint256 amount);
    event GovernanceActionNotified(address indexed user, uint256 newActionCount);
    event PlatformTotalUpdated(uint256 newTotal);
    event ContractUpdated(string contractType, address newAddress);
    event AuthorizedContractUpdated(address indexed contractAddr, bool authorized);
    event LayerZeroMessageReceived(uint32 srcEid, string functionName, string data);
    
    constructor(address _owner, address _openworkToken, address _endpoint) OAppCore(_endpoint, _owner) Ownable(msg.sender) {
        openworkToken = IERC20(_openworkToken);
        _initializeRewardBands();
        _initializeGovernanceRewardBands();
        transferOwnership(_owner);
    }

    // ==================== LAYERZERO MESSAGE HANDLING ====================
    
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal override {
        string memory message = abi.decode(_message, (string));
        
        // Parse the function call from the message
        bytes memory messageBytes = bytes(message);
        uint256 colonIndex = _findFirstColon(messageBytes);
        require(colonIndex > 0, "Invalid message format");
        
        string memory functionName = _substring(message, 0, colonIndex);
        string memory data = _substring(message, colonIndex + 1, bytes(message).length);
        
        emit LayerZeroMessageReceived(_origin.srcEid, functionName, data);
        
        // Route to appropriate function
        if (_compareStrings(functionName, "createProfile")) {
            _handleCreateProfile(data);
        } else if (_compareStrings(functionName, "updateRewardsOnPayment")) {
            _handleUpdateRewardsOnPayment(data);
        } else if (_compareStrings(functionName, "notifyGovernanceAction")) {
            _handleNotifyGovernanceAction(data);
        } else {
            revert("Unknown function");
        }
    }

    // ==================== MESSAGE PARSING HELPERS ====================
    
    function _findFirstColon(bytes memory data) private pure returns (uint256) {
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == 0x3A) { // ASCII for ':'
                return i;
            }
        }
        return 0;
    }
    
    function _substring(string memory str, uint256 startIndex, uint256 endIndex) private pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
    
    function _compareStrings(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    function _splitByColon(string memory data) private pure returns (string[] memory) {
        bytes memory dataBytes = bytes(data);
        uint256 colonCount = 0;
        
        // Count colons
        for (uint256 i = 0; i < dataBytes.length; i++) {
            if (dataBytes[i] == 0x3A) {
                colonCount++;
            }
        }
        
        string[] memory parts = new string[](colonCount + 1);
        uint256 partIndex = 0;
        uint256 startIndex = 0;
        
        for (uint256 i = 0; i <= dataBytes.length; i++) {
            if (i == dataBytes.length || dataBytes[i] == 0x3A) {
                bytes memory part = new bytes(i - startIndex);
                for (uint256 j = startIndex; j < i; j++) {
                    part[j - startIndex] = dataBytes[j];
                }
                parts[partIndex] = string(part);
                partIndex++;
                startIndex = i + 1;
            }
        }
        
        return parts;
    }
    
    function _hexStringToAddress(string memory s) private pure returns (address) {
        bytes memory ss = bytes(s);
        require(ss.length == 42, "Invalid address length");
        require(ss[0] == '0' && ss[1] == 'x', "Invalid address format");
        
        bytes memory addr = new bytes(20);
        for (uint256 i = 0; i < 20; i++) {
            addr[i] = bytes1(_fromHexChar(uint8(ss[2 + i * 2])) * 16 + _fromHexChar(uint8(ss[3 + i * 2])));
        }
        return address(uint160(bytes20(addr)));
    }
    
    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
            return c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f')) {
            return 10 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F')) {
            return 10 + c - uint8(bytes1('A'));
        }
        revert("Invalid hex character");
    }
    
    function _stringToUint(string memory s) private pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] >= 0x30 && b[i] <= 0x39) {
                result = result * 10 + (uint256(uint8(b[i])) - 48);
            }
        }
        return result;
    }

    // ==================== MESSAGE HANDLERS ====================
    
    function _handleCreateProfile(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 2, "Invalid createProfile data");
        
        address user = _hexStringToAddress(parts[0]);
        address referrer = _hexStringToAddress(parts[1]);
        
        createProfile(user, referrer);
    }
    
    function _handleUpdateRewardsOnPayment(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 3, "Invalid updateRewardsOnPayment data");
        
        address jobGiver = _hexStringToAddress(parts[0]);
        address jobTaker = _hexStringToAddress(parts[1]);
        uint256 amount = _stringToUint(parts[2]);
        
        updateRewardsOnPayment(jobGiver, jobTaker, amount);
    }
    
    function _handleNotifyGovernanceAction(string memory data) private {
        string[] memory parts = _splitByColon(data);
        require(parts.length == 1, "Invalid notifyGovernanceAction data");
        
        address account = _hexStringToAddress(parts[0]);
        
        notifyGovernanceAction(account);
    }
    
    // CONTRACT SETUP FUNCTIONS
    
    function setOpenworkToken(address _token) external onlyOwner {
        openworkToken = IERC20(_token);
        emit ContractUpdated("OpenworkToken", _token);
    }
    
    function setMainDAO(address _mainDAO) external onlyOwner {
        mainDAO = IMainDAO(_mainDAO);
        emit ContractUpdated("MainDAO", _mainDAO);
    }
    
    function setAuthorizedContract(address _contract, bool _authorized) external onlyOwner {
        authorizedContracts[_contract] = _authorized;
        emit AuthorizedContractUpdated(_contract, _authorized);
    }
    
    // REWARD BANDS INITIALIZATION
    
    function _initializeRewardBands() private {
        // Job-based reward bands
        rewardBands.push(RewardBand(0, 500 * 1e6, 100000 * 1e18));
        rewardBands.push(RewardBand(500 * 1e6, 1000 * 1e6, 50000 * 1e18));
        rewardBands.push(RewardBand(1000 * 1e6, 2000 * 1e6, 25000 * 1e18));
        rewardBands.push(RewardBand(2000 * 1e6, 4000 * 1e6, 12500 * 1e18));
        rewardBands.push(RewardBand(4000 * 1e6, 8000 * 1e6, 6250 * 1e18));
        rewardBands.push(RewardBand(8000 * 1e6, 16000 * 1e6, 3125 * 1e18));
        rewardBands.push(RewardBand(16000 * 1e6, 32000 * 1e6, 1562 * 1e18));
        rewardBands.push(RewardBand(32000 * 1e6, 64000 * 1e6, 781 * 1e18));
        rewardBands.push(RewardBand(64000 * 1e6, 128000 * 1e6, 391 * 1e18));
        rewardBands.push(RewardBand(128000 * 1e6, 256000 * 1e6, 195 * 1e18));
        rewardBands.push(RewardBand(256000 * 1e6, 512000 * 1e6, 98 * 1e18));
        rewardBands.push(RewardBand(512000 * 1e6, 1024000 * 1e6, 49 * 1e18));
        rewardBands.push(RewardBand(1024000 * 1e6, 2048000 * 1e6, 24 * 1e18));
        rewardBands.push(RewardBand(2048000 * 1e6, 4096000 * 1e6, 12 * 1e18));
        rewardBands.push(RewardBand(4096000 * 1e6, 8192000 * 1e6, 6 * 1e18));
        rewardBands.push(RewardBand(8192000 * 1e6, 16384000 * 1e6, 3 * 1e18));
        rewardBands.push(RewardBand(16384000 * 1e6, 32768000 * 1e6, 15 * 1e17));
        rewardBands.push(RewardBand(32768000 * 1e6, 65536000 * 1e6, 75 * 1e16));
        rewardBands.push(RewardBand(65536000 * 1e6, 131072000 * 1e6, 38 * 1e16));
        rewardBands.push(RewardBand(131072000 * 1e6, type(uint256).max, 19 * 1e16));
    }
    
    function _initializeGovernanceRewardBands() private {
        // Governance action reward bands
        governanceRewardBands.push(GovernanceRewardBand(0, 500 * 1e18, 100000 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(500 * 1e18, 1000 * 1e18, 50000 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(1000 * 1e18, 2000 * 1e18, 25000 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(2000 * 1e18, 4000 * 1e18, 12500 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(4000 * 1e18, 8000 * 1e18, 6250 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(8000 * 1e18, 16000 * 1e18, 3125 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(16000 * 1e18, 32000 * 1e18, 1562 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(32000 * 1e18, 64000 * 1e18, 781 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(64000 * 1e18, 128000 * 1e18, 391 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(128000 * 1e18, 256000 * 1e18, 196 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(256000 * 1e18, 512000 * 1e18, 98 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(512000 * 1e18, 1024000 * 1e18, 49 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(1024000 * 1e18, 2048000 * 1e18, 24 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(2048000 * 1e18, 4096000 * 1e18, 12 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(4096000 * 1e18, 8192000 * 1e18, 6 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(8192000 * 1e18, 16384000 * 1e18, 3 * 1e18));
        governanceRewardBands.push(GovernanceRewardBand(16384000 * 1e18, 32768000 * 1e18, 15 * 1e17));
        governanceRewardBands.push(GovernanceRewardBand(32768000 * 1e18, 65536000 * 1e18, 75 * 1e16));
        governanceRewardBands.push(GovernanceRewardBand(65536000 * 1e18, 131072000 * 1e18, 38 * 1e16));
        governanceRewardBands.push(GovernanceRewardBand(131072000 * 1e18, 262144000 * 1e18, 19 * 1e16));
    }
    
    // PROFILE AND PAYMENT FUNCTIONS CALLED BY LOCAL CONTRACT
    
    function createProfile(address user, address referrer) public {
        require(user != address(0), "Invalid user address");
        
        if (referrer != address(0) && referrer != user) {
            userReferrers[user] = referrer;
        }
        
        emit ProfileCreated(user, referrer);
    }
    
    function updateRewardsOnPayment(address jobGiver, address jobTaker, uint256 amount) public {
        require(jobGiver != address(0) && jobTaker != address(0), "Invalid addresses");
        require(amount > 0, "Amount must be greater than 0");
        
        // Update platform total by adding this payment
        currentTotalPlatformPayments += amount;
        emit PlatformTotalUpdated(currentTotalPlatformPayments);
        
        // Get referrers from internal mapping
        address jobGiverReferrer = userReferrers[jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        // Calculate reward distribution
        uint256 jobGiverAmount = amount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        // Deduct referral bonuses from job giver's amount
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = amount / 10; // 10% referral bonus
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = amount / 10; // 10% referral bonus
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        // Accumulate earnings for job giver (after deducting referral amounts)
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(jobGiver, jobGiverAmount);
        }
        
        // Accumulate earnings for referrers
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        
        emit PaymentProcessed(jobGiver, jobTaker, amount, currentTotalPlatformPayments);
    }
    
    function _accumulateJobTokens(address user, uint256 amountUSDT) private {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + amountUSDT;
        
        // Calculate tokens based on progressive bands
        uint256 tokensToAward = calculateTokensForRange(currentCumulative, newCumulative);
        
        // Update user's cumulative earnings and total tokens
        userCumulativeEarnings[user] = newCumulative;
        userTotalOWTokens[user] += tokensToAward;
        
        emit TokensEarned(user, tokensToAward, newCumulative, userTotalOWTokens[user]);
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
    
    // GOVERNANCE REWARDS FUNCTIONS
    
    function notifyGovernanceAction(address account) public {
        governanceActionCount[account]++;
        emit GovernanceActionNotified(account, governanceActionCount[account]);
    }
    
    function getCurrentGovernanceRewardPerAction() public view returns (uint256) {
        for (uint256 i = 0; i < governanceRewardBands.length; i++) {
            if (currentTotalPlatformPayments >= governanceRewardBands[i].minValue && 
                currentTotalPlatformPayments <= governanceRewardBands[i].maxValue) {
                return governanceRewardBands[i].rewardPerAction;
            }
        }
        
        // If platform value exceeds all bands, return the lowest reward
        if (governanceRewardBands.length > 0) {
            return governanceRewardBands[governanceRewardBands.length - 1].rewardPerAction;
        }
        
        return 0;
    }
    
    function calculateTotalEligibleRewards(address user) public view returns (uint256) {
        uint256 actions = governanceActionCount[user];
        if (actions == 0) return 0;
        
        // Get total accumulated earnings from job-based rewards
        uint256 totalJobEarnings = userCumulativeEarnings[user];
        
        // Calculate reward per action based on current platform total
        uint256 rewardPerAction = getCurrentGovernanceRewardPerAction();
        
        // Total rewards = governance actions × reward per action
        // But user can only claim proportional to their job earnings
        uint256 maxPossibleRewards = actions * rewardPerAction;
        
        // User can claim rewards proportional to their contribution to platform
        if (currentTotalPlatformPayments == 0) return 0;
        
        uint256 userProportion = (totalJobEarnings * 1e18) / currentTotalPlatformPayments;
        uint256 eligibleRewards = (maxPossibleRewards * userProportion) / 1e18;
        
        return eligibleRewards;
    }
    
    function getClaimableRewards(address user) public view returns (uint256) {
        uint256 totalEligible = calculateTotalEligibleRewards(user);
        uint256 alreadyClaimed = claimedGovernanceRewards[user];
        
        if (totalEligible <= alreadyClaimed) return 0;
        return totalEligible - alreadyClaimed;
    }
    
    function claimRewards() external nonReentrant {
        require(governanceActionCount[msg.sender] > 0, "No governance actions performed");
        require(userCumulativeEarnings[msg.sender] > 0, "No earnings to base rewards on");
        
        uint256 claimableAmount = getClaimableRewards(msg.sender);
        require(claimableAmount > 0, "No rewards to claim");
        
        // Check contract has enough tokens
        require(openworkToken.balanceOf(address(this)) >= claimableAmount, "Insufficient contract balance");
        
        // Update claimed amount
        claimedGovernanceRewards[msg.sender] += claimableAmount;
        
        // Transfer tokens to user
        require(openworkToken.transfer(msg.sender, claimableAmount), "Token transfer failed");
        
        emit GovernanceRewardsClaimed(msg.sender, claimableAmount);
    }
    
    // VIEW FUNCTIONS
    
    function getUserJobRewardInfo(address user) external view returns (
        uint256 cumulativeEarnings,
        uint256 totalJobTokens
    ) {
        return (userCumulativeEarnings[user], userTotalOWTokens[user]);
    }
    
    function getUserGovernanceRewardInfo(address user) external view returns (
        uint256 totalGovernanceActions,
        uint256 totalEligibleRewards,
        uint256 claimedAmount,
        uint256 claimableAmount,
        uint256 currentRewardPerAction
    ) {
        totalGovernanceActions = governanceActionCount[user];
        totalEligibleRewards = calculateTotalEligibleRewards(user);
        claimedAmount = claimedGovernanceRewards[user];
        claimableAmount = getClaimableRewards(user);
        currentRewardPerAction = getCurrentGovernanceRewardPerAction();
    }
    
    function getUserAllRewardInfo(address user) external view returns (
        uint256 cumulativeJobEarnings,
        uint256 totalJobTokens,
        uint256 totalGovernanceActions,
        uint256 totalEligibleRewards,
        uint256 claimedGovernanceRewards_,
        uint256 claimableGovernanceRewards,
        uint256 currentRewardPerAction
    ) {
        cumulativeJobEarnings = userCumulativeEarnings[user];
        totalJobTokens = userTotalOWTokens[user];
        totalGovernanceActions = governanceActionCount[user];
        totalEligibleRewards = calculateTotalEligibleRewards(user);
        claimedGovernanceRewards_ = claimedGovernanceRewards[user];
        claimableGovernanceRewards = getClaimableRewards(user);
        currentRewardPerAction = getCurrentGovernanceRewardPerAction();
    }
    
    function getUserReferrer(address user) external view returns (address) {
        return userReferrers[user];
    }
    
    function getCurrentTotalPlatformPayments() external view returns (uint256) {
        return currentTotalPlatformPayments;
    }
    
    function getRewardBandsCount() external view returns (uint256) {
        return rewardBands.length;
    }
    
    function getRewardBand(uint256 index) external view returns (uint256 minAmount, uint256 maxAmount, uint256 owPerDollar) {
        require(index < rewardBands.length, "Invalid band index");
        RewardBand memory band = rewardBands[index];
        return (band.minAmount, band.maxAmount, band.owPerDollar);
    }
    
    function getGovernanceRewardBandsCount() external view returns (uint256) {
        return governanceRewardBands.length;
    }
    
    function getGovernanceRewardBand(uint256 index) external view returns (uint256 minValue, uint256 maxValue, uint256 rewardPerAction) {
        require(index < governanceRewardBands.length, "Invalid band index");
        GovernanceRewardBand memory band = governanceRewardBands[index];
        return (band.minValue, band.maxValue, band.rewardPerAction);
    }
    
    function getCurrentGovernanceBandIndex() external view returns (uint256) {
        for (uint256 i = 0; i < governanceRewardBands.length; i++) {
            if (currentTotalPlatformPayments >= governanceRewardBands[i].minValue && 
                currentTotalPlatformPayments <= governanceRewardBands[i].maxValue) {
                return i;
            }
        }
        return governanceRewardBands.length > 0 ? governanceRewardBands.length - 1 : 0;
    }
    
    // Calculate job tokens for a specific amount without updating state
    function calculateJobTokensForAmount(address user, uint256 additionalAmount) external view returns (uint256) {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + additionalAmount;
        return calculateTokensForRange(currentCumulative, newCumulative);
    }
    
    // ADMIN FUNCTIONS
    
    function updatePlatformTotal(uint256 newTotal) external onlyOwner {
        require(newTotal >= currentTotalPlatformPayments, "Cannot decrease platform total");
        currentTotalPlatformPayments = newTotal;
        emit PlatformTotalUpdated(newTotal);
    }
    
    function emergencyUpdateUserJobRewards(address user, uint256 newCumulativeEarnings, uint256 newTotalTokens) external onlyOwner {
        userCumulativeEarnings[user] = newCumulativeEarnings;
        userTotalOWTokens[user] = newTotalTokens;
    }
    
    function emergencyUpdateUserGovernanceRewards(address user, uint256 newActionCount, uint256 newClaimedAmount) external onlyOwner {
        governanceActionCount[user] = newActionCount;
        claimedGovernanceRewards[user] = newClaimedAmount;
    }
    
    // Emergency token withdrawal
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(openworkToken.transfer(owner(), amount), "Token transfer failed");
    }
}