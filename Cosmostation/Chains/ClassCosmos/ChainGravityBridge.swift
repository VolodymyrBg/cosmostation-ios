//
//  ChainGravityBridge.swift
//  Cosmostation
//
//  Created by yongjoo jung on 2023/10/04.
//  Copyright © 2023 wannabit. All rights reserved.
//

import Foundation

class ChainGravityBridge: BaseChain  {
    
    override init() {
        super.init()
        
        name = "Gravity Bridge"
        tag = "gravity-bridge118"
        chainImg = "chainGravitybridge"
        apiName = "gravity-bridge"
        accountKeyType = AccountKeyType(.COSMOS_Secp256k1, "m/44'/118'/0'/0/X")
        
        
        cosmosEndPointType = .UseGRPC
        stakeDenom = "ugraviton"
        bechAccountPrefix = "gravity"
        validatorPrefix = "gravityvaloper"
        grpcHost = "grpc-gravity-bridge.cosmostation.io"
        lcdUrl = "https://lcd-gravity-bridge.cosmostation.io/"
    }
}
