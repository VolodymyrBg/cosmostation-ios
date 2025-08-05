//
//  ChainSei.swift
//  Cosmostation
//
//  Created by yongjoo jung on 2023/10/04.
//  Copyright © 2023 wannabit. All rights reserved.
//

import Foundation

class ChainSei: BaseChain {
    
    override init() {
        super.init()
        
        name = "Sei"
        tag = "sei118"
        chainImg = "chainSei"
        isDefault = false
        apiName = "sei"
        accountKeyType = AccountKeyType(.COSMOS_Secp256k1, "m/44'/118'/0'/0/X")
        
        
        cosmosEndPointType = .UseLCD
        stakeDenom = "usei"
        bechAccountPrefix = "sei"
        validatorPrefix = "seivaloper"
        grpcHost = "grpc-sei.cosmostation.io"
        lcdUrl = "https://lcd-sei.cosmostation.io/"
    }
}
