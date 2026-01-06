# Openwork Contract Addresses - January 2026

## Arbitrum Sepolia

### OpenworkGenesis (Implementation) - UPGRADED
- **Address:** `0xc1d22b12eEac0275833A9Be8E8AB2373BD0Bb6aA`
- **TX Hash:** `0x0d855c7b49ac301ef29cffbb733acb5b61a5e99ca150696669bea623b58775e8`
- **Previous Implementation:** `0x3e4f48dfb659D0844AbFDbdDb307B8D28f24be7b`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Upgrade TX:** `0x710e34c588acaea6fa85a1db909db81a2087259dec7d47de070ae5a8c1ecf8a2`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/openwork-genesis-4-jan.sol`
- **Upgrade Notes:** Added no-op updateMemberActivity() function for NativeDAO compatibility. Shortened require messages to fit under 24KB limit. TODO: Implement full activity tracking in future update.

### OpenworkGenesis (Proxy) - UPGRADED
- **Address:** `0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`
- **TX Hash:** `0x8ff9ec9afc671c0bfb40a3e75c2340ea2c70afe86831ac1a0dd928abe38bb4f5`
- **Implementation:** `0xc1d22b12eEac0275833A9Be8E8AB2373BD0Bb6aA`
- **Owner:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### OpenWorkRewardsContract (Implementation)
- **Address:** `0xCc9b4b183AdB83FcB14f21bf50497852512fa6fA`
- **TX Hash:** `0x33f25324b630a34e6851d0524101f16f869649ec7b79fa6d2ddb0c7052029c63`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/native-rewards-mainnet.sol`

### OpenWorkRewardsContract (Proxy) - INITIALIZED
- **Address:** `0x15CCa7C81A46059A46E794e6d0114c8cd9856715`
- **TX Hash:** `0x9f9d89c1de16f43efdfa46e6002e7d8bcdac828645080437c70674e1c60e721c`
- **Init TX:** `0x1adde9a78009e7becb8e1fa6e41eab99e5f231b285ca50db29003883d0e8da28`
- **Implementation:** `0xCc9b4b183AdB83FcB14f21bf50497852512fa6fA`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, jobContract=`0x68093a84D63FB508bdc6A099CCc1292CE33Bb513`, genesis=`0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### NativeOpenWorkJobContract / NOWJC (Implementation) - UPGRADED
- **Address:** `0xb56133D6af7e90083b6d0DdB210e51B0Cd17D805`
- **TX Hash:** `0xbf058d7a31add6f46c925595c3dc60a5b8215fd5f44811f9f48d04bb7f768178`
- **Previous Implementation:** `0xD9B0Ddd08aDde13ea582e3a4f367B0D7307093f3`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Upgrade TX:** `0xe5b3e884a9512e55caebca8a5c9ff16c744938ebb43e73730d58497fbe5bb17f`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/nowjc.sol`
- **Upgrade Notes:** Added teamTokensAllocated() view function to proxy team token queries to Native Rewards contract for NativeDAO voting power integration

### NativeOpenWorkJobContract / NOWJC (Proxy) - INITIALIZED & UPGRADED
- **Address:** `0x68093a84D63FB508bdc6A099CCc1292CE33Bb513`
- **TX Hash:** `0x9575ac96a656fcecc63e7ce6ac015b40d6b12978030b8e33b391541e05721a16`
- **Init TX:** `0xc1b78a4392b2d4f9ce6b52346f208dca5d85b5cb2a2844dee09758a27843f650`
- **Implementation:** `0xb56133D6af7e90083b6d0DdB210e51B0Cd17D805`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, bridge=`0xbCB4401e000bBbc9918030807c164d50d4dF9bc7`, genesis=`0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`, rewardsContract=`0x15CCa7C81A46059A46E794e6d0114c8cd9856715`, usdcToken=`0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`, cctpReceiver=`0xD22C85d18D188D37FD9D38974420a6BD68fFC315`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### NativeChainBridge (Non-Upgradeable)
- **Address:** `0xbCB4401e000bBbc9918030807c164d50d4dF9bc7`
- **TX Hash:** `0x953adbb3598c90874ba4ce7577d9a2d20769293314489007342d175da2e88b36`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Constructor Args:** endpoint=`0x6EDCE65403992e310A62460808c4b910D972f10f`, owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, mainChainEid=`40231`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/native-bridge.sol`

### CCTPv2TransceiverWithRewardsDynamic (Non-Upgradeable)
- **Address:** `0xD22C85d18D188D37FD9D38974420a6BD68fFC315`
- **TX Hash:** `0xfac6f2cbda618cf68c5154a6d2fc0a8b8dfbc6289fc5f385ec7b9935a136e845`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Constructor Args:** tokenMessenger=`0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`, messageTransmitter=`0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`, usdc=`0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/cctp-transceiver.sol`

### NativeDAO (Implementation) - UPGRADED (Jan 5)
- **Address:** `0xccce7077eC511B93BF4eff26eA0E093d6eF9F9fe`
- **TX Hash:** `0x60a4df1530e2b30add24c37a596fec26296b0ea7ad92f989f27b45735c8550b0`
- **Previous Implementation:** `0x77B53c3927fea2A4ebbeC144344Bee8FF243D95c`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Upgrade TX:** `0x871cfaa8765501556e068d9e562d8808dc94f3f608aae57cf7e4260975277a5f`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/native-dao.sol`
- **Upgrade Notes:** Added ActivityTracker integration for member activity tracking

### NativeDAO (Proxy) - INITIALIZED & UPGRADED
- **Address:** `0xB7Fb55CC44547fa9143431B71946fAC16D9EE357`
- **TX Hash:** `0x8e6f371ffe4ab660d1d46c176ab14292e3f6f802f349e5de20e5907cce4afb19`
- **Implementation:** `0xccce7077eC511B93BF4eff26eA0E093d6eF9F9fe`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, bridge=`0xbCB4401e000bBbc9918030807c164d50d4dF9bc7`, genesis=`0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### NativeAthena (Implementation) - UPGRADED (Jan 5)
- **Address:** `0x91cA073936A5EEe39f597D545ccE0A1AF63FeFF8`
- **TX Hash:** `0x6f85c110a5e1ded7bda1dc7137f0f7f136f2deaea71cb1b0ae1aea189bc05995`
- **Previous Implementation:** `0x0ad0306EAfCBf121Ed9990055b89e1249011455F`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Upgrade TX:** `0xc4c75a2c6a05217213698f493f97ca7548b045bbb8ef2d57da521d9575766ffe`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/native-athena.sol`
- **Upgrade Notes:** Added ActivityTracker integration, admin pattern (admins mapping + mainDAO), restricted updateOracleActiveStatus() to admins/OracleManager

### NativeAthena (Proxy) - INITIALIZED & UPGRADED
- **Address:** `0x20Ec5833261d9956399c3885b22439837a6eD7b2`
- **TX Hash:** `0x74ebc9039d6933b3aa36571dac9736152509b8da82fe3d7beb511516ebb62fca`
- **Implementation:** `0x91cA073936A5EEe39f597D545ccE0A1AF63FeFF8`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, daoContract=`0xB7Fb55CC44547fa9143431B71946fAC16D9EE357`, genesis=`0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`, nowjContract=`0x68093a84D63FB508bdc6A099CCc1292CE33Bb513`, usdcToken=`0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### NativeAthenaOracleManager (Implementation) - UPGRADED (Jan 5)
- **Address:** `0x5Ce4790511A7313AB55d678C4bCa7e910dD56324`
- **TX Hash:** `0x876c8e9ce6b3c1da18e216c68d9a8f3be9703470a509f41e454d87e4ccebe61f`
- **Previous Implementation:** `0xd8Ba6A37Ba9ee222593e6CbF005273897dd06c98`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Upgrade TX:** `0x5c50e0c05a66766f7c502df7cea116647ae57304346a888a31654e1ca1af19ee`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/native-athena-oracle-manager-4-jan.sol`
- **Upgrade Notes:** Added ActivityTracker integration, auto-activate oracle on creation with members

### NativeAthenaOracleManager (Proxy) - INITIALIZED & UPGRADED
- **Address:** `0x32eceb266A07262B15308cc626B261E7d7C5E215`
- **TX Hash:** `0xfc2a6ede4036aa87606c6c2e3830d1fd4203c9be2939c34adf560d40e860f3be`
- **Implementation:** `0x5Ce4790511A7313AB55d678C4bCa7e910dD56324`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, genesis=`0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`, nativeAthena=`0x20Ec5833261d9956399c3885b22439837a6eD7b2`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### ActivityTracker (Implementation) - NEW (Jan 5)
- **Address:** `0x206b2999000e45fA981698AA4F3E6dA6fcc0F711`
- **TX Hash:** (deployed by WALL1)
- **Deployer:** `0xaA6816876280c5A685Baf3D9c214A092c7f3F6Ef`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/activity-tracker.sol`

### ActivityTracker (Proxy) - NEW (Jan 5)
- **Address:** `0x36B6417228ADd2EF231E2676F00251736c6f8d06`
- **TX Hash:** `0x444314fe013e7e752a7d7c302948d706b90006b9bce0b13257dd47fc387163d8`
- **Implementation:** `0x206b2999000e45fA981698AA4F3E6dA6fcc0F711`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/activity-tracker.sol`
- **Notes:** Stores memberLastActivity and oracleActiveStatus mappings. Authorized callers: NativeAthena, NativeDAO, OracleManager

### ProfileGenesis (Implementation)
- **Address:** `0xF749d2C217CFE08912768b23e84ec546aabDC4F0`
- **TX Hash:** `0x2f11a9ca6e24fbc18babc43727cb54268db2253dcbe36025dc965e474fb329b0`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/profile-genesis.sol`

### ProfileGenesis (Proxy) - INITIALIZED
- **Address:** `0x8c6bD1B1d8EFcF11c2B9D4c732e537e28d81870e`
- **TX Hash:** `0xbf4e99d70bfe6a8c14fd7ed77299819be4c725ec13dee9d16c2e193c9967ca4c`
- **Implementation:** `0xF749d2C217CFE08912768b23e84ec546aabDC4F0`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### ProfileManager (Implementation)
- **Address:** `0x90D9dFFDA90Cfe8138847F4F45994fD5d74A7270`
- **TX Hash:** `0x5f6d77e5947e855d5138ccefa518fbd23725521162d81a615854464af5a6deec`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/profile-manager.sol`

### ProfileManager (Proxy) - INITIALIZED
- **Address:** `0x79d45FDA099E149a2bb263f29A2BE82afAEedC2D`
- **TX Hash:** `0x02f1b360b33705eed83bae13f39a48364e81dd01c9bb48717b00d5fee21d8890`
- **Implementation:** `0x90D9dFFDA90Cfe8138847F4F45994fD5d74A7270`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, bridge=`0xbCB4401e000bBbc9918030807c164d50d4dF9bc7`, genesis=`0xCfb3de1501A3d4619d9E57CEAE75f5Dc5D86497f`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

---

## OP Sepolia (Local Chain)

### LOWJC / CrossChainLocalOpenWorkJobContract (Implementation)
- **Address:** `0x130c9e93AA22ec3556BeBEbcDe9B257aADEC73B9`
- **TX Hash:** `0x1b6007a3372a824b561893230561cea705bd329a262535ef9a97872b03db1196`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/lowjc.sol`

### LOWJC / CrossChainLocalOpenWorkJobContract (Proxy) - INITIALIZED
- **Address:** `0x2F4Da95c8b84447605809a38f3a5a42CbCEeE885`
- **TX Hash:** `0x7968ab2ebc3203d28bbd1a2c1e1b3747176c2fa3e10d094ee59f85b1f4da7332`
- **Init TX:** `0xbaa265b6da9fb1d5b3357d5bc4c789459c56e557523a03fc33d181a8e27ca705`
- **Implementation:** `0x130c9e93AA22ec3556BeBEbcDe9B257aADEC73B9`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, usdcToken=`0x5fd84259d66Cd46123540766Be93DFE6D43130D7`, chainId=`40232`, bridge=`0xF069BE11c655270038f89DECFF4d9155D0910C95`, cctpSender=`0x2139Ef959b7C83fF853DB8882C258E586e07E9BE`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### LocalAthena (Implementation)
- **Address:** `0xb7891AD8f2C76f73f4f4097dD794e8def07f8f77`
- **TX Hash:** `0x48302c1a8ae3531001f1418751cb3f223ca40d614097032509abb5df7c0b2f40`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/athena-client.sol`

### LocalAthena (Proxy) - INITIALIZED
- **Address:** `0x07B66752021580Ab9E0445d1A4a52E4Cf84901F6`
- **TX Hash:** `0x7f2ed883f6cec4e7f064d57f6950d3716ccedc0091bdecdd4a5a80c4416b0110`
- **Init TX:** `0x9d8289a56e6f379bc80069f7753c93412c402232b2744e669e6067182be38fa8`
- **Implementation:** `0xb7891AD8f2C76f73f4f4097dD794e8def07f8f77`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, usdcToken=`0x5fd84259d66Cd46123540766Be93DFE6D43130D7`, chainId=`40232`, bridge=`0xF069BE11c655270038f89DECFF4d9155D0910C95`, cctpSender=`0x2139Ef959b7C83fF853DB8882C258E586e07E9BE`, nativeAthenaRecipient=`0x20Ec5833261d9956399c3885b22439837a6eD7b2`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### LocalBridge / LayerZeroBridge (Non-Upgradeable)
- **Address:** `0xF069BE11c655270038f89DECFF4d9155D0910C95`
- **TX Hash:** `0xc02502d8bb8970defac30b9b414d72f1bea4a65d9fcb6104755e9aee78a0038a`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Constructor Args:** endpoint=`0x6EDCE65403992e310A62460808c4b910D972f10f`, owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, nativeChainEid=`40231`, mainChainEid=`40161`, thisLocalChainEid=`40232`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/local-bridge.sol`

### CCTPv2TransceiverWithRewardsDynamic (Non-Upgradeable)
- **Address:** `0x2139Ef959b7C83fF853DB8882C258E586e07E9BE`
- **TX Hash:** `0xf87d268deda981d367d588d1463b0d9e759ccae4d034474d232720d3c5f23c7d`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Constructor Args:** tokenMessenger=`0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA`, messageTransmitter=`0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275`, usdc=`0x5fd84259d66Cd46123540766Be93DFE6D43130D7`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/cctp-transceiver.sol`

---

## ETH Sepolia (Main Chain)

### MainRewardsContract (Implementation)
- **Address:** `0xbe3606c54926b8d8125a7Cb5bcA4Ea8D442A23Da`
- **TX Hash:** `0xa238330d48ee72a8e2643e325861ebf58a8206a5d7f9ec8939ad5681960daeff`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/main-rewards.sol`

### MainRewardsContract (Proxy)
- **Address:** `0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C`
- **TX Hash:** `0xc3b6a534d47e9f1717240d886f071e451c8151004f34c54abd62995154dc8679`
- **Implementation:** `0xbe3606c54926b8d8125a7Cb5bcA4Ea8D442A23Da`
- **Init TX:** `0x6eb9321ffddf83200a15ab8ebdb3866cef6390933b9dc6863bb3b03971fe1d10`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, openworkToken=`0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd`, bridge=`0xa3346fF590717664efEc8424B2890aC3a7Bd1161`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### MainDAO (Implementation)
- **Address:** `0x2b3eE2E9627AB40F6cBE083B7966381c5e226747`
- **TX Hash:** `0xdf640ee66640281a2103b7c0003c0ba06374ceae5f78f346a9486c9b5c06fc8f`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/main-dao.sol`

### MainDAO (Proxy)
- **Address:** `0x43eBB3d1db00AEb3af1689b231EaEF066273805f`
- **TX Hash:** `0x032eab2265d051b842764f1b2dac3396a32f29f7d2cbf26d9bb036d454b895bf`
- **Implementation:** `0x2b3eE2E9627AB40F6cBE083B7966381c5e226747`
- **Init TX:** `0x09efa2c8f8f6a1ecf539fe5230e3152258439ec484288208e0b2b50a7c167044`
- **Init Params:** owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, openworkToken=`0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd`, chainId=`40161`, bridge=`0xa3346fF590717664efEc8424B2890aC3a7Bd1161`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/proxy.sol`

### OpenworkToken (Non-Upgradeable)
- **Address:** `0xB124516d543d169FE1E9E4fe7C5473e287eB9Fcd`
- **TX Hash:** `0xce35b30751a90da380e8bcd41e9d4b50c2bffc394fede7079b1e2ef2475ed11c`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Constructor Args:** initialOwner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, mainRewardsContract=`0x8993E4b6CD79278Ad6E1efAE7938e9063CAD3A8C`, daoAddress=`0x43eBB3d1db00AEb3af1689b231EaEF066273805f`
- **Token Distribution:** 750M to MainRewardsContract Proxy, 250M to MainDAO Proxy, 0 to owner
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/openwork-token.sol`

### MainBridge (Non-Upgradeable)
- **Address:** `0xa3346fF590717664efEc8424B2890aC3a7Bd1161`
- **TX Hash:** `0xf51d42807b37456758313a3b27c3da9b2e8521f86cffdc9c4351e807865fb38c`
- **Deployer:** `0xfD08836eeE6242092a9c869237a8d122275b024A`
- **Constructor Args:** endpoint=`0x6EDCE65403992e310A62460808c4b910D972f10f`, owner=`0xfD08836eeE6242092a9c869237a8d122275b024A`, nativeChainEid=`40231`
- **Source:** `src/suites/openwork-full-contract-suite-1-Jan-version/main-chain-bridge.sol`
