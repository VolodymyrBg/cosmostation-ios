//
//  ChainLike.swift
//  Cosmostation
//
//  Created by yongjoo jung on 2023/10/04.
//  Copyright © 2023 wannabit. All rights reserved.
//

import Foundation

class ChainLike: BaseChain  {
    
    override init() {
        super.init()
        
        name = "Likecoin"
        tag = "likecoin118"
        chainImg = "chainLike"
        apiName = "likecoin"
        accountKeyType = AccountKeyType(.COSMOS_Secp256k1, "m/44'/118'/0'/0/X")
        
        
        cosmosEndPointType = .UseLCD
        stakeDenom = "nanolike"
        bechAccountPrefix = "like"
        validatorPrefix = "likevaloper"
        grpcHost = "grpc-likecoin-mainnet.pikaser.net"
        lcdUrl = "https://mainnet-node.like.co/"
    }
}
