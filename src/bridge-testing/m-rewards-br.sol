// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { OApp, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IMainDAO {
    function getEarner(address earnerAddress) external view returns (address, uint256, uint256, uint256);
}

contract RewardsReceiver is OApp, ReentrancyGuard {
    IERC20 public openworkToken;
    IMainDAO public mainDAO;
    
    mapping(address => address) public userReferrers;
    
    struct RewardBand {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 owPerDollar;
    }
    
    struct GovernanceRewardBand {
        uint256 minValue;
        uint256 maxValue;
        uint256 rewardPerAction;
    }
    
    mapping(address => uint256) public userCumulativeEarnings;
    mapping(address => uint256) public userTotalOWTokens;
    mapping(address => uint256) public claimedGovernanceRewards;
    mapping(address => uint256) public governanceActionCount;
    
    uint256 public currentTotalPlatformPayments;
    
    RewardBand[] public rewardBands;
    GovernanceRewardBand[] public governanceRewardBands;
    mapping(address => bool) public authorizedContracts;
    
    // Events
    event ProfileCreated(address indexed user, address indexed referrer);
    event PaymentProcessed(address indexed jobGiver, address indexed jobTaker, uint256 amount, uint256 newPlatformTotal);
    event TokensEarned(address indexed user, uint256 tokensEarned, uint256 newCumulativeEarnings, uint256 newTotalTokens);
    event GovernanceRewardsClaimed(address indexed user, uint256 amount);
    event GovernanceActionNotified(address indexed user, uint256 newActionCount);
    event PlatformTotalUpdated(uint256 newTotal);
    event ContractUpdated(string contractType, address newAddress);
    event AuthorizedContractUpdated(address indexed contractAddr, bool authorized);
    
    constructor(address _endpoint, address _owner, address _openworkToken) OApp(_endpoint, _owner) Ownable(_owner) {
        openworkToken = IERC20(_openworkToken);
        _initializeRewardBands();
        _initializeGovernanceRewardBands();
    }
    
    function _lzReceive(
        Origin calldata,
        bytes32,
        bytes calldata payload,
        address,
        bytes calldata
    ) internal override {
        string memory message = abi.decode(payload, (string));
        _processMessage(message);
    }
    
    function _processMessage(string memory message) internal {
        string[] memory parts = _split(message, ":");
        require(parts.length > 0, "Invalid message format");
        
        string memory action = parts[0];
        
        if (_compareStrings(action, "createProfile")) {
            _handleCreateProfile(parts);
        } else if (_compareStrings(action, "updateRewardsOnPayment")) {
            _handleUpdateRewardsOnPayment(parts);
        } else if (_compareStrings(action, "notifyGovernanceAction")) {
            _handleNotifyGovernanceAction(parts);
        }
    }
    
    function _handleCreateProfile(string[] memory parts) internal {
        require(parts.length == 3, "Invalid createProfile format");
        address user = _parseAddress(parts[1]);
        address referrer = _parseAddress(parts[2]);
        
        require(user != address(0), "Invalid user address");
        
        if (referrer != address(0) && referrer != user) {
            userReferrers[user] = referrer;
        }
        
        emit ProfileCreated(user, referrer);
    }
    
    function _handleUpdateRewardsOnPayment(string[] memory parts) internal {
        require(parts.length == 4, "Invalid updateRewardsOnPayment format");
        address jobGiver = _parseAddress(parts[1]);
        address jobTaker = _parseAddress(parts[2]);
        uint256 amount = _parseUint(parts[3]);
        
        require(jobGiver != address(0) && jobTaker != address(0), "Invalid addresses");
        require(amount > 0, "Amount must be greater than 0");
        
        currentTotalPlatformPayments += amount;
        emit PlatformTotalUpdated(currentTotalPlatformPayments);
        
        address jobGiverReferrer = userReferrers[jobGiver];
        address jobTakerReferrer = userReferrers[jobTaker];
        
        uint256 jobGiverAmount = amount;
        uint256 jobGiverReferrerAmount = 0;
        uint256 jobTakerReferrerAmount = 0;
        
        if (jobGiverReferrer != address(0) && jobGiverReferrer != jobGiver) {
            jobGiverReferrerAmount = amount / 10;
            jobGiverAmount -= jobGiverReferrerAmount;
        }
        
        if (jobTakerReferrer != address(0) && jobTakerReferrer != jobTaker && jobTakerReferrer != jobGiverReferrer) {
            jobTakerReferrerAmount = amount / 10;
            jobGiverAmount -= jobTakerReferrerAmount;
        }
        
        if (jobGiverAmount > 0) {
            _accumulateJobTokens(jobGiver, jobGiverAmount);
        }
        
        if (jobGiverReferrerAmount > 0) {
            _accumulateJobTokens(jobGiverReferrer, jobGiverReferrerAmount);
        }
        
        if (jobTakerReferrerAmount > 0) {
            _accumulateJobTokens(jobTakerReferrer, jobTakerReferrerAmount);
        }
        
        emit PaymentProcessed(jobGiver, jobTaker, amount, currentTotalPlatformPayments);
    }
    
    function _handleNotifyGovernanceAction(string[] memory parts) internal {
        require(parts.length == 2, "Invalid notifyGovernanceAction format");
        address account = _parseAddress(parts[1]);
        
        governanceActionCount[account]++;
        emit GovernanceActionNotified(account, governanceActionCount[account]);
    }
    
    function _accumulateJobTokens(address user, uint256 amountUSDT) private {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + amountUSDT;
        uint256 tokensToAward = calculateTokensForRange(currentCumulative, newCumulative);
        
        userCumulativeEarnings[user] = newCumulative;
        userTotalOWTokens[user] += tokensToAward;
        
        emit TokensEarned(user, tokensToAward, newCumulative, userTotalOWTokens[user]);
    }
    
    function calculateTokensForRange(uint256 fromAmount, uint256 toAmount) public view returns (uint256) {
        if (fromAmount >= toAmount) return 0;
        
        uint256 totalTokens = 0;
        uint256 currentAmount = fromAmount;
        
        for (uint256 i = 0; i < rewardBands.length && currentAmount < toAmount; i++) {
            RewardBand memory band = rewardBands[i];
            
            if (band.maxAmount <= currentAmount) continue;
            
            uint256 bandStart = currentAmount > band.minAmount ? currentAmount : band.minAmount;
            uint256 bandEnd = toAmount < band.maxAmount ? toAmount : band.maxAmount;
            
            if (bandStart < bandEnd) {
                uint256 amountInBand = bandEnd - bandStart;
                uint256 tokensInBand = (amountInBand * band.owPerDollar) / 1e6;
                totalTokens += tokensInBand;
                currentAmount = bandEnd;
            }
        }
        
        return totalTokens;
    }
    
    function getCurrentGovernanceRewardPerAction() public view returns (uint256) {
        for (uint256 i = 0; i < governanceRewardBands.length; i++) {
            if (currentTotalPlatformPayments >= governanceRewardBands[i].minValue && 
                currentTotalPlatformPayments <= governanceRewardBands[i].maxValue) {
                return governanceRewardBands[i].rewardPerAction;
            }
        }
        
        if (governanceRewardBands.length > 0) {
            return governanceRewardBands[governanceRewardBands.length - 1].rewardPerAction;
        }
        
        return 0;
    }
    
    function calculateTotalEligibleRewards(address user) public view returns (uint256) {
        uint256 actions = governanceActionCount[user];
        if (actions == 0) return 0;
        
        uint256 totalJobEarnings = userCumulativeEarnings[user];
        uint256 rewardPerAction = getCurrentGovernanceRewardPerAction();
        uint256 maxPossibleRewards = actions * rewardPerAction;
        
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
        require(openworkToken.balanceOf(address(this)) >= claimableAmount, "Insufficient contract balance");
        
        claimedGovernanceRewards[msg.sender] += claimableAmount;
        require(openworkToken.transfer(msg.sender, claimableAmount), "Token transfer failed");
        
        emit GovernanceRewardsClaimed(msg.sender, claimableAmount);
    }
    
    function _initializeRewardBands() private {
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
    
    // Utility functions
    function _split(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        bytes memory delimiterBytes = bytes(delimiter);
        
        uint256 count = 1;
        for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) count++;
        }
        
        string[] memory parts = new string[](count);
        uint256 partIndex = 0;
        uint256 startIndex = 0;
        
        for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                parts[partIndex] = _substring(str, startIndex, i);
                partIndex++;
                startIndex = i + delimiterBytes.length;
                i += delimiterBytes.length - 1;
            }
        }
        parts[partIndex] = _substring(str, startIndex, strBytes.length);
        
        return parts;
    }
    
    function _substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }
    
    function _parseAddress(string memory str) internal pure returns (address) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length == 42, "Invalid address length");
        
        uint256 result = 0;
        for (uint256 i = 2; i < 42; i++) {
            result *= 16;
            uint8 b = uint8(strBytes[i]);
            if (b >= 48 && b <= 57) result += b - 48;
            else if (b >= 97 && b <= 102) result += b - 87;
            else if (b >= 65 && b <= 70) result += b - 55;
        }
        
        return address(uint160(result));
    }
    
    function _parseUint(string memory str) internal pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        uint256 result = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            uint8 b = uint8(strBytes[i]);
            require(b >= 48 && b <= 57, "Invalid number");
            result = result * 10 + (b - 48);
        }
        return result;
    }
    
    function _compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    // Admin functions
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
    
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(openworkToken.transfer(owner(), amount), "Token transfer failed");
    }
    
    // View functions
    function getUserJobRewardInfo(address user) external view returns (uint256 cumulativeEarnings, uint256 totalJobTokens) {
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
    
    function calculateJobTokensForAmount(address user, uint256 additionalAmount) external view returns (uint256) {
        uint256 currentCumulative = userCumulativeEarnings[user];
        uint256 newCumulative = currentCumulative + additionalAmount;
        return calculateTokensForRange(currentCumulative, newCumulative);
    }
}