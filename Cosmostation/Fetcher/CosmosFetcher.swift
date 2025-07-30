//
//  CosmosFetcher.swift
//  Cosmostation
//
//  Created by yongjoo jung on 7/15/24.
//  Copyright © 2024 wannabit. All rights reserved.
//

import Foundation
import SwiftProtobuf
import GRPC
import NIO
import SwiftyJSON
import Alamofire


class CosmosFetcher {
    
    var chain: BaseChain!
    var cosmosLcdAuth: JSON?
    var cosmosGrpcAuth: Google_Protobuf_Any?
    
    var cosmosAccountNumber: UInt64?
    var cosmosSequenceNum: UInt64?
    var cosmosBalances: [Cosmos_Base_V1beta1_Coin]?
    var cosmosAvailable: [Cosmos_Base_V1beta1_Coin]?
    var cosmosDelegations = [Cosmos_Staking_V1beta1_DelegationResponse]()
    var cosmosUnbondings: [Cosmos_Staking_V1beta1_UnbondingDelegation]?
    var cosmosRewards: [Cosmos_Distribution_V1beta1_DelegationDelegatorReward]?
    var cosmosRewardCoins: [Cosmos_Base_V1beta1_Coin]?
    var cosmosCommissions =  [Cosmos_Base_V1beta1_Coin]()
    var rewardAddress:  String?
    var cosmosValidators = [Cosmos_Staking_V1beta1_Validator]()
    var cosmosBaseFees = [Cosmos_Base_V1beta1_DecCoin]()
    
    var mintscanCw20Tokens = [MintscanToken]()
    var mintscanCw721List = [JSON]()
    var cw721Models = [Cw721Model]()
    
    var grpcConnection: ClientConnection?
    
    
    
    init(_ chain: BaseChain) {
        self.chain = chain
    }
    
    func fetchCosmosAvailables() async -> Bool {
        cosmosAvailable = [Cosmos_Base_V1beta1_Coin]()
        if let available = try? await fetchSpendableBalance() {
            self.cosmosAvailable = available
        }
        return true
    }
    
    func fetchCosmosBalances() async -> Bool {
        cosmosBalances = [Cosmos_Base_V1beta1_Coin]()
        if let balance = try? await fetchBalance() {
            self.cosmosBalances = balance
        }
        return true
    }
    
    func fetchCosmosData(_ id: Int64) async -> Bool {
        mintscanCw20Tokens.removeAll()
        mintscanCw721List.removeAll()
        cosmosBalances = nil
        cosmosDelegations.removeAll()
        cosmosUnbondings = nil
        cosmosRewards = nil
        cosmosRewardCoins = nil
        cosmosCommissions.removeAll()
        rewardAddress = nil
        cosmosBaseFees.removeAll()
        
        do {
            if let balance = try await fetchBalance(),
               let available = try await fetchSpendableBalance(),
               let delegations = try? await fetchDelegation(),
               let unbonding = try? await fetchUnbondings(),
               let rewards = try? await fetchRewards(),
               let commission = try? await fetchCommission(),
               let rewardaddr = try? await fetchRewardAddress(),
               let baseFees = try? await fetchBaseFee() {
                
                self.mintscanCw20Tokens =  BaseData.instance.mintscanCw20Tokens?.filter({ $0.chainName == chain.apiName }) ?? []
                self.mintscanCw721List = BaseData.instance.mintscanCw721?.filter({ $0["chain"].stringValue == chain.apiName }) ?? []

                self.cosmosBalances = balance
                self.cosmosAvailable = available
                
                delegations?.forEach({ delegation in
                    if (delegation.balance.amount != "0") {
                        self.cosmosDelegations.append(delegation)
                    }
                })
                self.cosmosUnbondings = unbonding
                self.cosmosRewards = rewards
                commission?.commission.forEach { commi in
                    if (commi.getAmount().compare(NSDecimalNumber.zero).rawValue > 0) {
                        self.cosmosCommissions.append(Cosmos_Base_V1beta1_Coin(commi.denom, commi.getAmount()))
                    }
                }
                self.rewardAddress = rewardaddr?.replacingOccurrences(of: "\"", with: "")
                
                baseFees?.forEach({ basefee in
                    if (BaseData.instance.getAsset(chain.apiName, basefee.denom) != nil) {
                        self.cosmosBaseFees.append(basefee)
                    }
                })
                self.cosmosBaseFees.sort {
                    if ($0.denom == chain.stakeDenom) { return true }
                    if ($1.denom == chain.stakeDenom) { return false }
                    return false
                }
                let userDisplaytoken = BaseData.instance.getDisplayCw20s(id, self.chain.tag)
                await mintscanCw20Tokens.concurrentForEach { cw20 in
                    cw20.type = "cw20"
                    if (userDisplaytoken == nil) {
                        if (cw20.wallet_preload == true) {
                            await self.fetchCw20Balance(cw20)
                        }
                    } else {
                        if (userDisplaytoken?.contains(cw20.address!) == true) {
                            await self.fetchCw20Balance(cw20)
                        }
                    }
                }
            }
            return true
            
        } catch {
            print("fetchCosmos error \(error) ", chain.tag)
            return false
        }
    }
    
    func fetchCosmosValidators() async -> Bool {
        if (cosmosValidators.count > 0) { return true }
        if let bonded = try? await fetchBondedValidator(),
           let unbonding = try? await fetchUnbondingValidator(),
           let unbonded = try? await fetchUnbondedValidator() {
            
            cosmosValidators.append(contentsOf: bonded ?? [])
            cosmosValidators.append(contentsOf: unbonding ?? [])
            cosmosValidators.append(contentsOf: unbonded ?? [])
            
            cosmosValidators = cosmosValidators.map { validator in
                var updatedValidator = validator
                updatedValidator.description_p.moniker = validator.description_p.moniker.trimmingCharacters(in: .whitespaces)
                return updatedValidator
            }
            
            cosmosValidators.sort {
                if ($0.description_p.moniker == "Cosmostation") { return true }
                if ($1.description_p.moniker == "Cosmostation") { return false }
                if ($0.jailed && !$1.jailed) { return false }
                if (!$0.jailed && $1.jailed) { return true }
                return Double($0.tokens)! > Double($1.tokens)!
            }
            return true
        }
        return false
    }
    
    
    func isActiveValidator(_ validator: Cosmos_Staking_V1beta1_Validator) -> Bool {
        if let maxProviderConsensusCnt = chain.getMaxProviderConsensusValidator() {
            
            let bonded = cosmosValidators.filter { $0.status == .bonded }
            
            let active = bonded.sorted {
                if ($0.jailed && !$1.jailed) { return false }
                if (!$0.jailed && $1.jailed) { return true }
                return Double($0.tokens)! > Double($1.tokens)!
            }.prefix(maxProviderConsensusCnt)
            
            return active.contains(validator)
            
        } else {
            return validator.status == .bonded
        }
    }
    
    func denomValue(_ denom: String, _ usd: Bool? = false) -> NSDecimalNumber {
        if (denom == chain.stakeDenom) {
            return balanceValue(denom, usd).adding(rewardValue(denom, usd))
                .adding(delegationValueSum(usd)).adding(unbondingValueSum(usd)).adding(commissionValue(denom, usd))
            
        } else {
            return balanceValue(denom, usd).adding(rewardValue(denom, usd))
                .adding(commissionValue(denom, usd))
        }
    }
    
    func allStakingDenomAmount() -> NSDecimalNumber {
        return balanceAmount(chain.stakeDenom!).adding(delegationAmountSum())
            .adding(unbondingAmountSum()).adding(rewardAmountSum(chain.stakeDenom!)).adding(commissionAmount(chain.stakeDenom!))
    }
    
    func allCoinValue(_ usd: Bool? = false) -> NSDecimalNumber {
        return balanceValueSum(usd).adding(delegationValueSum(usd))
            .adding(unbondingValueSum(usd)).adding(rewardValueSum(usd)).adding(commissionValueSum(usd))
    }
    
    func valueCoinCnt() -> Int {
        return cosmosBalances?.filter({ BaseData.instance.getAsset(chain.apiName, $0.denom) != nil }).count ?? 0
    }
    
    func valueTokenCnt(_ id: Int64) -> Int {
        if let tokens = BaseData.instance.getDisplayCw20s(id, chain.tag) {
            return tokens.count
            
        } else {
            return mintscanCw20Tokens.filter({ $0.wallet_preload == true }).count
        }
    }

    func isRewardAddressChanged() -> Bool {
        return chain.bechAddress != rewardAddress
    }
    
    
    
    // data handleing
    func tokenValue(_ address: String, _ usd: Bool? = false) -> NSDecimalNumber {
        if chain.isSupportCw20() {
            if let tokenInfo = mintscanCw20Tokens.filter({ $0.address == address }).first {
                let msPrice = BaseData.instance.getPrice(tokenInfo.coinGeckoId, usd)
                return msPrice.multiplying(by: tokenInfo.getAmount()).multiplying(byPowerOf10: -tokenInfo.decimals!, withBehavior: handler6)
            }
        }
        return NSDecimalNumber.zero
    }
    
    func allTokenValue(_ id: Int64, _ usd: Bool? = false) -> NSDecimalNumber {
        var result = NSDecimalNumber.zero
        
        if let tokens = BaseData.instance.getDisplayCw20s(id, chain.tag) {
            mintscanCw20Tokens.filter({ tokens.contains($0.address ?? "") }).forEach { tokenInfo in
                let msPrice = BaseData.instance.getPrice(tokenInfo.coinGeckoId, usd)
                let value = msPrice.multiplying(by: tokenInfo.getAmount()).multiplying(byPowerOf10: -tokenInfo.decimals!, withBehavior: handler6)
                result = result.adding(value)
            }
            
        } else {
            mintscanCw20Tokens.filter({ $0.wallet_preload == true }).forEach { tokenInfo in
                let msPrice = BaseData.instance.getPrice(tokenInfo.coinGeckoId, usd)
                let value = msPrice.multiplying(by: tokenInfo.getAmount()).multiplying(byPowerOf10: -tokenInfo.decimals!, withBehavior: handler6)
                result = result.adding(value)
            }
            
        }
        return result
    }
    
    func availableAmount(_ denom: String) -> NSDecimalNumber {
        return NSDecimalNumber(string: cosmosAvailable?.filter { $0.denom == denom }.first?.amount ?? "0")
    }
    
    func availableValue(_ denom: String, _ usd: Bool? = false) -> NSDecimalNumber {
        let amount = availableAmount(denom)
        if (amount == NSDecimalNumber.zero) { return NSDecimalNumber.zero }
        if let msAsset = BaseData.instance.getAsset(chain.apiName, denom) {
            let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, usd)
            return msPrice.multiplying(by: amount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
        }
        return NSDecimalNumber.zero
    }
    
    func balanceAmount(_ denom: String) -> NSDecimalNumber {
        return NSDecimalNumber(string: cosmosBalances?.filter { $0.denom == denom }.first?.amount ?? "0")
    }
    
    func balanceValue(_ denom: String, _ usd: Bool? = false) -> NSDecimalNumber {
        let amount = balanceAmount(denom)
        if (amount == NSDecimalNumber.zero) { return NSDecimalNumber.zero }
        if let msAsset = BaseData.instance.getAsset(chain.apiName, denom) {
            let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, usd)
            return msPrice.multiplying(by: amount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
        }
        return NSDecimalNumber.zero
    }
    
    func balanceValueSum(_ usd: Bool? = false) -> NSDecimalNumber {
        var result =  NSDecimalNumber.zero
        cosmosBalances?.forEach { balance in
            result = result.adding(balanceValue(balance.denom, usd))
        }
        return result
    }
    
    func vestingAmount(_ denom: String) -> NSDecimalNumber {
        let balance = NSDecimalNumber(string: cosmosBalances?.filter { $0.denom == denom }.first?.amount ?? "0")
        let available = NSDecimalNumber(string: cosmosAvailable?.filter { $0.denom == denom }.first?.amount ?? "0")
        
        if (balance.compare(available).rawValue > 0) {
            return balance.subtracting(available)
        } else {
            return NSDecimalNumber.zero
        }
    }
    
    func vestingValue(_ denom: String, _ usd: Bool? = false) -> NSDecimalNumber {
        if let msAsset = BaseData.instance.getAsset(chain.apiName, denom) {
            let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, usd)
            let amount = vestingAmount(denom)
            return msPrice.multiplying(by: amount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
        }
        return NSDecimalNumber.zero
    }
    
    //for special case (ex: Coreum) 25.06
    func lockedAmount(_ denom: String) -> NSDecimalNumber {
        return NSDecimalNumber.zero
    }
    
    func lockedValue(_ denom: String, _ usd: Bool? = false) -> NSDecimalNumber {
        return NSDecimalNumber.zero
    }
    
    func delegationAmountSum() -> NSDecimalNumber {
        var sum = NSDecimalNumber.zero
        cosmosDelegations.forEach({ delegation in
            sum = sum.adding(NSDecimalNumber(string: delegation.balance.amount))
        })
        return sum
    }
    
    func delegationValueSum(_ usd: Bool? = false) -> NSDecimalNumber {
        if let msAsset = BaseData.instance.getAsset(chain.apiName, chain.stakeDenom!) {
            let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, usd)
            let amount = delegationAmountSum()
            return msPrice.multiplying(by: amount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
        }
        return NSDecimalNumber.zero
    }
    
    func unbondingAmountSum() -> NSDecimalNumber {
        var sum = NSDecimalNumber.zero
        cosmosUnbondings?.forEach({ unbonding in
            for entry in unbonding.entries {
                sum = sum.adding(NSDecimalNumber(string: entry.balance))
            }
        })
        return sum
    }
    
    func unbondingValueSum(_ usd: Bool? = false) -> NSDecimalNumber {
        if let msAsset = BaseData.instance.getAsset(chain.apiName, chain.stakeDenom!) {
            let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, usd)
            let amount = unbondingAmountSum()
            return msPrice.multiplying(by: amount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
        }
        return NSDecimalNumber.zero
    }
    
    
    func rewardAmountSum(_ denom: String) -> NSDecimalNumber {
        var result =  NSDecimalNumber.zero
        cosmosRewards?.forEach({ reward in
            result = result.adding(NSDecimalNumber(string: reward.reward.filter{ $0.denom == denom }.first?.amount ?? "0"))
        })
        return result.multiplying(byPowerOf10: -18, withBehavior: handler0Down)
    }
    
    func rewardValue(_ denom: String, _ usd: Bool? = false) -> NSDecimalNumber {
        if let msAsset = BaseData.instance.getAsset(chain.apiName, denom) {
            let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, usd)
            let amount = rewardAmountSum(denom)
            return msPrice.multiplying(by: amount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
        }
        return NSDecimalNumber.zero
    }
    
    func rewardAllCoins() -> [Cosmos_Base_V1beta1_Coin] {
        if (cosmosRewardCoins != nil) { return cosmosRewardCoins! }
        cosmosRewardCoins = [Cosmos_Base_V1beta1_Coin]()
        cosmosRewards?.forEach({ reward in
            reward.reward.forEach { deCoin in
                if BaseData.instance.getAsset(chain.apiName, deCoin.denom) != nil {
                    let deCoinAmount = deCoin.getAmount()
                    if (deCoinAmount != NSDecimalNumber.zero) {
                        if let index = cosmosRewardCoins!.firstIndex(where: { $0.denom == deCoin.denom }) {
                            let exist = NSDecimalNumber(string: cosmosRewardCoins![index].amount)
                            let addes = exist.adding(deCoinAmount)
                            cosmosRewardCoins![index].amount = addes.stringValue
                        } else {
                            cosmosRewardCoins!.append(Cosmos_Base_V1beta1_Coin(deCoin.denom, deCoinAmount))
                        }
                    }
                }
            }
        })
        if let babylonBtcFetcher = (chain as? ChainBabylon)?.getBabylonBtcFetcher() {
            let btcStakingRewards = babylonBtcFetcher.btcStakedRewards
            btcStakingRewards.forEach { reward in
                if let index = cosmosRewardCoins?.firstIndex(where: { $0.denom == reward.denom }) {
                    let amount = NSDecimalNumber(string: cosmosRewardCoins?[index].amount)
                    cosmosRewardCoins?[index].amount = amount.adding(NSDecimalNumber(string: reward.amount)).stringValue
                } else {
                    cosmosRewardCoins?.append(Cosmos_Base_V1beta1_Coin(reward.denom, reward.amount))
                }
            }
        }
        return cosmosRewardCoins!
    }
    
    func rewardOtherDenomTypeCnts() -> Int {
        var denoms = [String]()
        rewardAllCoins().filter { $0.denom != chain.stakeDenom }.forEach { reward in
            if (denoms.contains(reward.denom) == false) {
                denoms.append(reward.denom)
            }
        }
        return denoms.count
    }
    
    func rewardValueSum(_ usd: Bool? = false) -> NSDecimalNumber {
        var result = NSDecimalNumber.zero
        rewardAllCoins().forEach { rewardCoin in
            if let msAsset = BaseData.instance.getAsset(chain.apiName, rewardCoin.denom) {
                let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, usd)
                let amount = NSDecimalNumber(string: rewardCoin.amount)
                let value = msPrice.multiplying(by: amount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
                result = result.adding(value)
            }
        }
        return result
    }
    
    func claimableRewards() -> [Cosmos_Distribution_V1beta1_DelegationDelegatorReward] {
        var result = [Cosmos_Distribution_V1beta1_DelegationDelegatorReward]()
        cosmosRewards?.forEach { reward in
            for i in 0..<reward.reward.count {
                let rewardAmount = NSDecimalNumber(string: reward.reward[i].amount).multiplying(byPowerOf10: -18, withBehavior: handler0Down)
                if let msAsset = BaseData.instance.getAsset(chain.apiName, reward.reward[i].denom) {
                    let calAmount = rewardAmount.multiplying(byPowerOf10: -msAsset.decimals!)
                    if chain is ChainBabylon {
                        if (calAmount.compare(NSDecimalNumber.init(string: "0")).rawValue > 0) {
                            result.append(reward)
                            break
                        }
                    } else {
                        if (calAmount.compare(NSDecimalNumber.init(string: "0.1")).rawValue > 0) {
                            result.append(reward)
                            break
                        }
                    }
                }
            }
            return
        }
        return result
    }
    
    func valueableRewards() -> [Cosmos_Distribution_V1beta1_DelegationDelegatorReward] {
        var result = [Cosmos_Distribution_V1beta1_DelegationDelegatorReward]()
        cosmosRewards?.forEach { reward in
            var eachRewardValue = NSDecimalNumber.zero
            for i in 0..<reward.reward.count {
                let rewardAmount = NSDecimalNumber(string: reward.reward[i].amount).multiplying(byPowerOf10: -18, withBehavior: handler0Down)
                if let msAsset = BaseData.instance.getAsset(chain.apiName, reward.reward[i].denom) {
                    let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, true)
                    let value = msPrice.multiplying(by: rewardAmount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
                    eachRewardValue = eachRewardValue.adding(value)
                    if (eachRewardValue.compare(NSDecimalNumber.init(string: "0.1")).rawValue >= 0) {
                        result.append(reward)
                        break
                    }
                }
            }
        }
        return result
    }
    
    func compoundableRewards() -> [Cosmos_Distribution_V1beta1_DelegationDelegatorReward] {
        var result = [Cosmos_Distribution_V1beta1_DelegationDelegatorReward]()
        cosmosRewards?.forEach { reward in
            if let rewardAmount = reward.reward.filter({ $0.denom == chain.stakeDenom }).first?.getAmount(),
               let msAsset = BaseData.instance.getAsset(chain.apiName, chain.stakeDenom!) {
                let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, true)
                let value = msPrice.multiplying(by: rewardAmount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
                if (value.compare(NSDecimalNumber.init(string: "0.1")).rawValue >= 0) {
                    result.append(reward)
                }
            }
        }
        return result
    }
    
    func commissionAmount(_ denom: String) -> NSDecimalNumber {
        return cosmosCommissions.filter { $0.denom == denom }.first?.getAmount() ?? NSDecimalNumber.zero
    }
    
    func commissionValue(_ denom: String, _ usd: Bool? = false) -> NSDecimalNumber {
        if let msAsset = BaseData.instance.getAsset(chain.apiName, denom) {
            let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId, usd)
            let amount = cosmosCommissions.filter { $0.denom == denom }.first?.getAmount() ?? NSDecimalNumber.zero
            return msPrice.multiplying(by: amount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
        }
        return NSDecimalNumber.zero
    }
    
    func commissionValueSum(_ usd: Bool? = false) -> NSDecimalNumber {
        var result =  NSDecimalNumber.zero
        cosmosCommissions.forEach { commi in
            result = result.adding(commissionValue(commi.denom, usd))
        }
        return result
    }
    
    func commissionOtherDenoms() -> Int {
        return cosmosCommissions.filter { $0.denom != chain.stakeDenom }.count
    }
    
    func delegatableAmount() -> NSDecimalNumber {
        return balanceAmount(chain.stakeDenom!)
    }
    
}

//about web3 call api
extension CosmosFetcher {
    
    func fetchBondedValidator() async throws -> [Cosmos_Staking_V1beta1_Validator]? {
        if (getEndpointType() == .UseGRPC) {
            let page = Cosmos_Base_Query_V1beta1_PageRequest.with { $0.limit = 300 }
            let req = Cosmos_Staking_V1beta1_QueryValidatorsRequest.with { $0.pagination = page; $0.status = "BOND_STATUS_BONDED" }
            return try await Cosmos_Staking_V1beta1_QueryNIOClient(channel: getClient()).validators(req).response.get().validators
        } else {
            let url = getLcd() + "cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=300"
            let response = try await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response.validators(.bonded)
        }
    }
    
    func fetchUnbondedValidator() async throws -> [Cosmos_Staking_V1beta1_Validator]? {
        if (getEndpointType() == .UseGRPC) {
            let page = Cosmos_Base_Query_V1beta1_PageRequest.with { $0.limit = 500 }
            let req = Cosmos_Staking_V1beta1_QueryValidatorsRequest.with { $0.pagination = page; $0.status = "BOND_STATUS_UNBONDED" }
            return try await Cosmos_Staking_V1beta1_QueryNIOClient(channel: getClient()).validators(req).response.get().validators
        } else {
            let url = getLcd() + "cosmos/staking/v1beta1/validators?status=BOND_STATUS_UNBONDED&pagination.limit=500"
            let response = try await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response.validators(.unbonded)
        }
    }
    
    func fetchUnbondingValidator() async throws -> [Cosmos_Staking_V1beta1_Validator]? {
        if (getEndpointType() == .UseGRPC) {
            let page = Cosmos_Base_Query_V1beta1_PageRequest.with { $0.limit = 500 }
            let req = Cosmos_Staking_V1beta1_QueryValidatorsRequest.with { $0.pagination = page; $0.status = "BOND_STATUS_UNBONDING" }
            return try await Cosmos_Staking_V1beta1_QueryNIOClient(channel: getClient()).validators(req).response.get().validators
        } else {
            let url = getLcd() + "cosmos/staking/v1beta1/validators?status=BOND_STATUS_UNBONDING&pagination.limit=500"
            let response = try await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response.validators(.unbonding)
        }
    }
    
    func fetchAuth() async throws {
        cosmosLcdAuth = nil
        cosmosGrpcAuth = nil
        cosmosAccountNumber = nil
        cosmosSequenceNum = nil
        
        if (getEndpointType() == .UseGRPC) {
            let req = Cosmos_Auth_V1beta1_QueryAccountRequest.with { $0.address = chain.bechAddress! }
            if let result = try? await Cosmos_Auth_V1beta1_QueryNIOClient(channel: getClient()).account(req, callOptions: getCallOptions()).response.get().account {
                cosmosGrpcAuth = result
                cosmosAccountNumber = result.accountInfos().1
                cosmosSequenceNum = result.accountInfos().2
            }
            
        } else {
            let url = getLcd() + "cosmos/auth/v1beta1/accounts/${address}".replacingOccurrences(of: "${address}", with: chain.bechAddress!)
            if let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value["account"] {
                cosmosLcdAuth = response
                cosmosAccountNumber = response.getAccountNum()
                cosmosSequenceNum = response.getSequenceNum()
            }
        }
    }
    
    func fetchBalance() async throws -> [Cosmos_Base_V1beta1_Coin]? {
        if (getEndpointType() == .UseGRPC) {
            let page = Cosmos_Base_Query_V1beta1_PageRequest.with { $0.limit = 2000 }
            let req = Cosmos_Bank_V1beta1_QueryAllBalancesRequest.with { $0.address = chain.bechAddress!; $0.pagination = page }
            return try await Cosmos_Bank_V1beta1_QueryNIOClient(channel: getClient()).allBalances(req, callOptions: getCallOptions()).response.get().balances
        } else {
            let url = getLcd() + "cosmos/bank/v1beta1/balances/${address}?pagination.limit=2000".replacingOccurrences(of: "${address}", with: chain.bechAddress!)
            let response = try await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response.balances()
        }
    }
    
    func fetchSpendableBalance() async throws -> [Cosmos_Base_V1beta1_Coin]? {
        if (getEndpointType() == .UseGRPC) {
            let page = Cosmos_Base_Query_V1beta1_PageRequest.with { $0.limit = 2000 }
            let req = Cosmos_Bank_V1beta1_QuerySpendableBalancesRequest.with { $0.address = chain.bechAddress!; $0.pagination = page }
            return try await Cosmos_Bank_V1beta1_QueryNIOClient(channel: getClient()).spendableBalances(req, callOptions: getCallOptions()).response.get().balances
        } else {
            let url = getLcd() + "cosmos/bank/v1beta1/spendable_balances/${address}?pagination.limit=2000".replacingOccurrences(of: "${address}", with: chain.bechAddress!)
            let response = try await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response.balances()
        }
    }
    
    func fetchDelegation() async throws -> [Cosmos_Staking_V1beta1_DelegationResponse]? {
        if (getEndpointType() == .UseGRPC) {
            let req = Cosmos_Staking_V1beta1_QueryDelegatorDelegationsRequest.with { $0.delegatorAddr = chain.bechAddress! }
            return try? await Cosmos_Staking_V1beta1_QueryNIOClient(channel: getClient()).delegatorDelegations(req, callOptions: getCallOptions()).response.get().delegationResponses
        } else {
            let url = getLcd() + "cosmos/staking/v1beta1/delegations/${address}".replacingOccurrences(of: "${address}", with: chain.bechAddress!)
            let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response?.delegations()
        }
    }
    
    func fetchUnbondings() async throws -> [Cosmos_Staking_V1beta1_UnbondingDelegation]? {
        if (getEndpointType() == .UseGRPC) {
            let req = Cosmos_Staking_V1beta1_QueryDelegatorUnbondingDelegationsRequest.with { $0.delegatorAddr = chain.bechAddress! }
            return try? await Cosmos_Staking_V1beta1_QueryNIOClient(channel: getClient()).delegatorUnbondingDelegations(req, callOptions: getCallOptions()).response.get().unbondingResponses
        } else {
            let url = getLcd() + "cosmos/staking/v1beta1/delegators/${address}/unbonding_delegations".replacingOccurrences(of: "${address}", with: chain.bechAddress!)
            let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response?.undelegations()
        }
    }
    
    func fetchRewards() async throws -> [Cosmos_Distribution_V1beta1_DelegationDelegatorReward]? {
        if (getEndpointType() == .UseGRPC) {
            let req = Cosmos_Distribution_V1beta1_QueryDelegationTotalRewardsRequest.with { $0.delegatorAddress = chain.bechAddress! }
            return try? await Cosmos_Distribution_V1beta1_QueryNIOClient(channel: getClient()).delegationTotalRewards(req, callOptions: getCallOptions()).response.get().rewards
        } else {
            let url = getLcd() + "cosmos/distribution/v1beta1/delegators/${address}/rewards".replacingOccurrences(of: "${address}", with: chain.bechAddress!)
            let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response?.rewards()
        }
    }
    
    func fetchCommission() async throws -> Cosmos_Distribution_V1beta1_ValidatorAccumulatedCommission? {
        if (chain.bechOpAddress == nil) { return nil }
        if (getEndpointType() == .UseGRPC) {
            let req = Cosmos_Distribution_V1beta1_QueryValidatorCommissionRequest.with { $0.validatorAddress = chain.bechOpAddress! }
            return try? await Cosmos_Distribution_V1beta1_QueryNIOClient(channel: getClient()).validatorCommission(req, callOptions: getCallOptions()).response.get().commission
        } else {
            let url = getLcd() + "cosmos/distribution/v1beta1/validators/${address}/commission".replacingOccurrences(of: "${address}", with: chain.bechOpAddress!)
            let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response?.commission()
        }
    }
    
    func fetchRewardAddress() async throws -> String? {
        if (getEndpointType() == .UseGRPC) {
            let req = Cosmos_Distribution_V1beta1_QueryDelegatorWithdrawAddressRequest.with { $0.delegatorAddress = chain.bechAddress! }
            return try? await Cosmos_Distribution_V1beta1_QueryNIOClient(channel: getClient()).delegatorWithdrawAddress(req, callOptions: getCallOptions()).response.get().withdrawAddress
        } else {
            let url = getLcd() + "cosmos/distribution/v1beta1/delegators/${address}/withdraw_address".replacingOccurrences(of: "${address}", with: chain.bechAddress!)
            let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response?.rewardAddress()
        }
    }
    
    func fetchOnChainProposals() async throws -> [MintscanProposal]? {
        var resultProposals = [MintscanProposal]()
        if (getEndpointType() == .UseGRPC) {
            let page = Cosmos_Base_Query_V1beta1_PageRequest.with { $0.reverse = true; $0.limit = 200 }
            let v1Req = Cosmos_Gov_V1_QueryProposalsRequest.with { $0.pagination = page }
            let v1betaReq = Cosmos_Gov_V1beta1_QueryProposalsRequest.with { $0.pagination = page }
            if let result = try? await Cosmos_Gov_V1_QueryNIOClient(channel: getClient()).proposals(v1Req, callOptions: getCallOptions()).response.get() {
                result.proposals.forEach { proposal in
                    resultProposals.append(MintscanProposal(proposal))
                }
            } else if let result = try? await Cosmos_Gov_V1beta1_QueryNIOClient(channel: getClient()).proposals(v1betaReq, callOptions: getCallOptions()).response.get() {
                result.proposals.forEach { proposal in
                    resultProposals.append(MintscanProposal(proposal))
                }
            }
            
        } else {
            let v1Url = getLcd() + "cosmos/gov/v1/proposals?pagination.limit=200&pagination.reverse=true"
            let v1beta1Url = getLcd() + "cosmos/gov/v1beta1/proposals?pagination.limit=200&pagination.reverse=true"
            if let proposals = try await AF.request(v1Url, method: .get).serializingDecodable(JSON.self).value["proposals"].array {
                proposals.forEach { proposal in
                    resultProposals.append(MintscanProposal(proposal))
                }
                
            } else if let proposals = try await AF.request(v1beta1Url, method: .get).serializingDecodable(JSON.self).value["proposals"].array {
                proposals.forEach { proposal in
                    resultProposals.append(MintscanProposal(proposal))
                }
            }
        }
        return resultProposals
    }
    
    func fetchOnChainProposalHistory(_ id: UInt64, _ address: String) async -> MintscanMyVotes? {
        if (getEndpointType() == .UseGRPC) {
            let v1Req = Cosmos_Gov_V1_QueryVoteRequest.with { $0.proposalID = id; $0.voter = address}
            let v1betaReq = Cosmos_Gov_V1beta1_QueryVoteRequest.with { $0.proposalID = id; $0.voter = address}
            if let result = try? await Cosmos_Gov_V1_QueryNIOClient(channel: getClient()).vote(v1Req, callOptions: getCallOptions()).response.get() {
                return .init(result.vote)
                
            } else if let result = try? await Cosmos_Gov_V1beta1_QueryNIOClient(channel: getClient()).vote(v1betaReq, callOptions: getCallOptions()).response.get() {
                return .init(result.vote)
            }

        } else {
            let v1Url = getLcd() + "cosmos/gov/v1/proposals/" + String(id) + "/votes/" + address
            let v1beta1Url = getLcd() + "cosmos/gov/v1beta1/proposals/" + String(id) + "/votes/" + address
            if let value = try? await AF.request(v1Url, method: .get).serializingDecodable(JSON.self).value, value["vote"].exists() {
                return .init(value["vote"])
                
            } else if let vote = try? await AF.request(v1beta1Url, method: .get).serializingDecodable(JSON.self).value["vote"] {
                return .init(vote)
            }
        }
        
        return nil
    }
    
    func simulateTx(_ simulTx: Cosmos_Tx_V1beta1_SimulateRequest) async throws -> UInt64? {
        if (getEndpointType() == .UseGRPC) {
            return try await Cosmos_Tx_V1beta1_ServiceNIOClient(channel: getClient()).simulate(simulTx, callOptions: getCallOptions()).response.get().gasInfo.gasUsed
        } else {
            let param: Parameters = ["txBytes": try! simulTx.tx.serializedData().base64EncodedString() ]
            let url = getLcd() + "cosmos/tx/v1beta1/simulate"
            let result = try await AF.request(url, method: .post, parameters: param, encoding: JSONEncoding.default, headers: [:]).serializingDecodable(JSON.self).value
            if let gasUsed = result["gas_info"]["gas_used"].string {
                return UInt64(gasUsed)
            } else {
                throw EmptyDataError.error(message: result["message"].stringValue)
            }
        }
    }
    
    func broadcastTx(_ broadTx: Cosmos_Tx_V1beta1_BroadcastTxRequest) async throws -> Cosmos_Base_Abci_V1beta1_TxResponse? {
        if (getEndpointType() == .UseGRPC) {
            return try await Cosmos_Tx_V1beta1_ServiceNIOClient(channel: getClient()).broadcastTx(broadTx, callOptions: getCallOptions()).response.get().txResponse
        } else {
            let param: Parameters = ["mode" : Cosmos_Tx_V1beta1_BroadcastMode.async.rawValue, "tx_bytes": try broadTx.txBytes.base64EncodedString() ]
            let url = getLcd() + "cosmos/tx/v1beta1/txs"
            let result = try await AF.request(url, method: .post, parameters: param, encoding: JSONEncoding.default, headers: [:]).serializingDecodable(JSON.self).value
            if (!result["tx_response"].isEmpty) {
                var response = Cosmos_Base_Abci_V1beta1_TxResponse()
                response.txhash = result["tx_response"]["txhash"].stringValue
                response.rawLog = result["tx_response"]["raw_log"].stringValue
                return response
            }
            throw AFError.explicitlyCancelled
        }
    }
    
    func fetchTx( _ hash: String) async throws -> Cosmos_Tx_V1beta1_GetTxResponse? {
        if (getEndpointType() == .UseGRPC) {
            let req = Cosmos_Tx_V1beta1_GetTxRequest.with { $0.hash = hash }
            return try await Cosmos_Tx_V1beta1_ServiceNIOClient(channel: getClient()).getTx(req, callOptions: getCallOptions()).response.get()
        } else {
            let url = getLcd() + "cosmos/tx/v1beta1/txs/${hash}".replacingOccurrences(of: "${hash}", with: hash)
            let result = try await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            if (!result["tx_response"].isEmpty) {
                var response = Cosmos_Tx_V1beta1_GetTxResponse()
                var txResponse = Cosmos_Base_Abci_V1beta1_TxResponse()
                txResponse.txhash = result["tx_response"]["txhash"].stringValue
                txResponse.code = result["tx_response"]["code"].uInt32Value
                txResponse.rawLog = result["tx_response"]["raw_log"].stringValue
                response.txResponse = txResponse
                return response
            }
            throw AFError.explicitlyCancelled
        }
    }
    
    func fetchIbcClient(_ ibcPath: MintscanPath) async throws -> UInt64? {
        if (getEndpointType() == .UseGRPC) {
            let req = Ibc_Core_Channel_V1_QueryChannelClientStateRequest.with {
                $0.channelID = ibcPath.getChannel()!
                $0.portID = ibcPath.getPort()!
            }
            if let result = try? await Ibc_Core_Channel_V1_QueryNIOClient(channel: getClient()).channelClientState(req, callOptions: getCallOptions()).response.get().identifiedClientState.clientState.value,
               let latestHeight = try? Ibc_Lightclients_Tendermint_V1_ClientState.init(serializedData: result).latestHeight.revisionNumber {
                return latestHeight
            }
        } else {
            let url = getLcd() + "ibc/core/channel/v1/channels/${channel}/ports/${port}/client_state".replacingOccurrences(of: "${channel}", with: ibcPath.getChannel()!).replacingOccurrences(of: "${port}", with: ibcPath.getPort()!)
            let result = try await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            if let revision_number = result["identified_client_state"]["client_state"]["latest_height"]["revision_number"].string {
                return UInt64(revision_number)
            }
        }
        return nil
    }
    
    func fetchLastBlock() async throws -> Int64? {
        if chain is ChainCelestia {
            let url = chain.lcdUrl + "cosmos/base/tendermint/v1beta1/blocks/latest"
            let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            if let height = response?["block"]["header"]["height"].string {
                return Int64(height)!
            }
            
        } else {
            if (getEndpointType() == .UseGRPC) {
                let req = Cosmos_Base_Tendermint_V1beta1_GetLatestBlockRequest()
                return try? await Cosmos_Base_Tendermint_V1beta1_ServiceNIOClient(channel: getClient()).getLatestBlock(req, callOptions: getCallOptions()).response.get().block.header.height
            } else {
                let url = getLcd() + "cosmos/base/tendermint/v1beta1/blocks/latest"
                let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value
                if let height = response?["block"]["header"]["height"].string {
                    return Int64(height)!
                }
            }
        }
        return nil
    }
    
    
    func fetchAllCw20Balance(_ id: Int64) async {
        if (chain.isSupportCw20() == false) { return }
        let userDisplaytoken = BaseData.instance.getDisplayCw20s(id, self.chain.tag)
        Task {
            await mintscanCw20Tokens.concurrentForEach { cw20 in
                if (userDisplaytoken == nil) {
                    if (cw20.wallet_preload == true) {
                        await self.fetchCw20Balance(cw20)
                    }
                } else {
                    if (userDisplaytoken?.contains(cw20.address!) == true) {
                        await self.fetchCw20Balance(cw20)
                    }
                }
            }
        }
    }
    
    func fetchCw20Balance(_ tokenInfo: MintscanToken) async {
        if (getEndpointType() == .UseGRPC) {
            let query: JSON = ["balance" : ["address" : self.chain.bechAddress!]]
            let queryBase64 = try! query.rawData(options: [.sortedKeys, .withoutEscapingSlashes]).base64EncodedString()
            let req = Cosmwasm_Wasm_V1_QuerySmartContractStateRequest.with {
                $0.address = tokenInfo.address!
                $0.queryData = Data(base64Encoded: queryBase64)!
            }
            if let response = try? await Cosmwasm_Wasm_V1_QueryNIOClient(channel: getClient()).smartContractState(req, callOptions: self.getCallOptions()).response.get() {
                let cw20balance = try? JSONDecoder().decode(JSON.self, from: response.data)
                tokenInfo.setAmount(cw20balance?["balance"].string ?? "0")
            }
        } else {
            let query: JSON = ["balance" : ["address" : self.chain.bechAddress!]]
            let queryBase64 = try! query.rawData(options: [.sortedKeys, .withoutEscapingSlashes]).base64EncodedString()
            let url = getLcd() + "cosmwasm/wasm/v1/contract/${address}/smart/${query_data}".replacingOccurrences(of: "${address}", with: tokenInfo.address!).replacingOccurrences(of: "${query_data}", with: queryBase64)
            if let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value["data"] {
                if let balance = response["balance"].string {
                    tokenInfo.setAmount(balance)
                }
            }
        }
    }
    
    func fetchCw20BalanceAmount(_ contractAddress: String) async throws -> NSDecimalNumber? {
        let query: JSON = ["balance" : ["address" : self.chain.bechAddress!]]
        let queryBase64 = try! query.rawData(options: [.sortedKeys, .withoutEscapingSlashes]).base64EncodedString()
        let req = Cosmwasm_Wasm_V1_QuerySmartContractStateRequest.with {
            $0.address = contractAddress
            $0.queryData = Data(base64Encoded: queryBase64)!
        }
        if let response = try await self.fetchSmartContractState(req) {
            return NSDecimalNumber(string: response["balance"].string)
        }
        return nil
    }
    
    
    func fetchAllCw721() {
        cw721Models.removeAll()
        Task {
            await mintscanCw721List.concurrentForEach { list in
                var tokens = [Cw721TokenModel]()
                if let tokenIds = try? await self.fetchCw721TokenIds(list) {
                    await tokenIds?["tokens"].arrayValue.concurrentForEach { tokenId in
                        if let tokenInfo = try? await self.fetchCw721TokenInfo(list, tokenId.stringValue) {
                            let tokenDetail = try? await AF.request(BaseNetWork.msNftDetail(self.chain.apiName, list["contractAddress"].stringValue, tokenId.stringValue), method: .get).serializingDecodable(JSON.self).value
                            tokens.append(Cw721TokenModel.init(tokenId.stringValue, tokenInfo!, tokenDetail))
                        }
                    }
                }
                if (!tokens.isEmpty) {
                    self.cw721Models.append(Cw721Model(list, tokens))
                }
            }
            DispatchQueue.main.async(execute: {
                self.cw721Models.sort {
                    return $0.info["id"].doubleValue < $1.info["id"].doubleValue
                }
                self.cw721Models.forEach { cw721Model in
                    cw721Model.sortId()
                }
                NotificationCenter.default.post(name: Notification.Name("FetchNFTs"), object: self.chain.tag, userInfo: nil)
            })
        }
    }
    
    func fetchCw721TokenIds(_ list: JSON) async throws -> JSON? {
        if (getEndpointType() == .UseGRPC) {
            let query: JSON = ["tokens" : ["owner" : self.chain.bechAddress!, "limit" : 50, "start_after" : "0"]]
            let queryBase64 = try! query.rawData(options: [.sortedKeys, .withoutEscapingSlashes]).base64EncodedString()
            let req = Cosmwasm_Wasm_V1_QuerySmartContractStateRequest.with {
                $0.address = list["contractAddress"].stringValue
                $0.queryData = Data(base64Encoded: queryBase64)!
            }
            if let result = try? await Cosmwasm_Wasm_V1_QueryNIOClient(channel: getClient()).smartContractState(req, callOptions: getCallOptions()).response.get().data,
               let tokenIds = try? JSONDecoder().decode(JSON.self, from: result), tokenIds["tokens"].arrayValue.count > 0 {
                return tokenIds
            }
        } else {
            let query: JSON = ["tokens" : ["owner" : self.chain.bechAddress!, "limit" : 50, "start_after" : "0"]]
            let queryBase64 = try! query.rawData(options: [.sortedKeys, .withoutEscapingSlashes]).base64EncodedString()
            let url = getLcd() + "cosmwasm/wasm/v1/contract/${address}/smart/${query_data}".replacingOccurrences(of: "${address}", with: list["contractAddress"].stringValue).replacingOccurrences(of: "${query_data}", with: queryBase64)
            return try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value["data"]
        }
        return nil
    }
    
    func fetchCw721TokenInfo(_ list: JSON, _ tokenId: String) async throws -> JSON? {
        if (getEndpointType() == .UseGRPC) {
            let query: JSON = ["nft_info" : ["token_id" : tokenId]]
            let queryBase64 = try! query.rawData(options: [.sortedKeys, .withoutEscapingSlashes]).base64EncodedString()
            let req = Cosmwasm_Wasm_V1_QuerySmartContractStateRequest.with {
                $0.address = list["contractAddress"].stringValue
                $0.queryData = Data(base64Encoded: queryBase64)!
            }
            if let result = try? await Cosmwasm_Wasm_V1_QueryNIOClient(channel: getClient()).smartContractState(req, callOptions: getCallOptions()).response.get().data,
               let tokenInfo = try? JSONDecoder().decode(JSON.self, from: result) {
                return tokenInfo
            }
        } else {
            let query: JSON = ["nft_info" : ["token_id" : tokenId]]
            let queryBase64 = try! query.rawData(options: [.sortedKeys, .withoutEscapingSlashes]).base64EncodedString()
            let url = getLcd() + "cosmwasm/wasm/v1/contract/${address}/smart/${query_data}".replacingOccurrences(of: "${address}", with: list["contractAddress"].stringValue).replacingOccurrences(of: "${query_data}", with: queryBase64)
            return try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value["data"]
        }
        return nil
    }
    
    func fetchBaseFee() async throws -> [Cosmos_Base_V1beta1_DecCoin]? {
        if (!chain.isSupportCosmosFeeMarket()) { return nil }
        if (getEndpointType() == .UseGRPC) {
            let req = Feemarket_Feemarket_V1_GasPricesRequest.init()
            return try? await Feemarket_Feemarket_V1_QueryNIOClient(channel: getClient()).gasPrices(req, callOptions: getCallOptions()).response.get().prices
        } else {
            let url = getLcd() + "feemarket/v1/gas_prices"
            let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            return response?.feeMarket()
        }
    }
    
    func updateBaseFee() async {
        cosmosBaseFees.removeAll()
        if (!chain.isSupportCosmosFeeMarket()) { return }
        if (getEndpointType() == .UseGRPC) {
            let req = Feemarket_Feemarket_V1_GasPricesRequest.init()
            if let baseFees = try? await Feemarket_Feemarket_V1_QueryNIOClient(channel: getClient()).gasPrices(req, callOptions: getCallOptions()).response.get().prices {
                baseFees.forEach({ basefee in
                    if (BaseData.instance.getAsset(chain.apiName, basefee.denom) != nil) {
                        self.cosmosBaseFees.append(basefee)
                    }
                })
                self.cosmosBaseFees.sort {
                    if ($0.denom == chain.stakeDenom) { return true }
                    if ($1.denom == chain.stakeDenom) { return false }
                    return false
                }
            }
            
        } else {
            let url = getLcd() + "feemarket/v1/gas_prices"
            let response = try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value
            if let result = response?.feeMarket() {
                result.forEach { basefee in
                    if (BaseData.instance.getAsset(chain.apiName, basefee.denom) != nil) {
                        self.cosmosBaseFees.append(basefee)
                    }
                }
                self.cosmosBaseFees.sort {
                    if ($0.denom == chain.stakeDenom) { return true }
                    if ($1.denom == chain.stakeDenom) { return false }
                    return false
                }
            }
        }
    }
    
    func fetchSmartContractState(_ request: Cosmwasm_Wasm_V1_QuerySmartContractStateRequest) async throws -> JSON? {
        if (getEndpointType() == .UseGRPC) {
            if let result = try? await Cosmwasm_Wasm_V1_QueryNIOClient(channel: getClient()).smartContractState(request, callOptions: getCallOptions()).response.get().data,
               let state = try? JSONDecoder().decode(JSON.self, from: result) {
                return state
            }
        } else {
            let url = getLcd() + "cosmwasm/wasm/v1/contract/${address}/smart/${query_data}".replacingOccurrences(of: "${address}", with: request.address).replacingOccurrences(of: "${query_data}", with: request.queryData.base64EncodedString())
            return try? await AF.request(url, method: .get).serializingDecodable(JSON.self).value["data"]
        }
        return nil
    }
    
    
    
    
    func getEndpointType() -> CosmosEndPointType? {
        let endpointType = UserDefaults.standard.integer(forKey: KEY_COSMOS_ENDPOINT_TYPE +  " : " + chain.name)
        if (endpointType == CosmosEndPointType.UseGRPC.rawValue) {
            return .UseGRPC
        } else if (endpointType == CosmosEndPointType.UseLCD.rawValue) {
            return .UseLCD
        } else if (endpointType == CosmosEndPointType.UseRPC.rawValue) {
            return .UseRPC
        } else {
            return chain.cosmosEndPointType
        }
    }
    
    func getLcd() -> String {
        var url = ""
        if let endpoint = UserDefaults.standard.string(forKey: KEY_CHAIN_LCD_ENDPOINT +  " : " + chain.name) {
            url = endpoint
        } else {
            url = chain.lcdUrl
        }
        if (url.last != "/") {
            return url + "/"
        }
        return url
    }
    
    func getGrpc() -> (host: String, port: Int) {
        if let endpoint = UserDefaults.standard.string(forKey: KEY_CHAIN_GRPC_ENDPOINT +  " : " + chain.name) {
            if (endpoint.components(separatedBy: ":").count == 2) {
                let host = endpoint.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
                let port = Int(endpoint.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
                return (host, port!)
            }
        }
        if (chain.grpcHost.components(separatedBy: ":").count == 2) {
            let host = chain.grpcHost.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            let port = Int(chain.grpcHost.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
            return (host, port!)
        }
        return (chain.grpcHost, chain.grpcPort)
    }
    
    func getClient() -> ClientConnection {
        if (grpcConnection == nil) {
            let group = PlatformSupport.makeEventLoopGroup(loopCount: 4)
            grpcConnection = ClientConnection.usingPlatformAppropriateTLS(for: group).connect(host: getGrpc().host, port: getGrpc().port)
        }
        return grpcConnection!
    }
    
    func getCallOptions() -> CallOptions {
        var callOptions = CallOptions()
        callOptions.timeLimit = TimeLimit.timeout(TimeAmount.milliseconds(20000))
        return callOptions
    }
}


extension JSON {
    
    func validators(_ status: Cosmos_Staking_V1beta1_BondStatus) -> [Cosmos_Staking_V1beta1_Validator]? {
        var result = [Cosmos_Staking_V1beta1_Validator]()
        self["validators"].array?.forEach({ validator in
            var temp = Cosmos_Staking_V1beta1_Validator()
            temp.operatorAddress = validator["operator_address"].stringValue
            temp.jailed = validator["jailed"].boolValue
            temp.tokens = validator["tokens"].stringValue
            temp.status = status
            
            var desription = Cosmos_Staking_V1beta1_Description()
            desription.moniker = validator["description"]["moniker"].stringValue
            desription.identity = validator["description"]["identity"].stringValue
            desription.website = validator["description"]["website"].stringValue
            desription.securityContact = validator["description"]["security_contact"].stringValue
            desription.details = validator["description"]["details"].stringValue
            temp.description_p = desription
            
            var commission = Cosmos_Staking_V1beta1_Commission()
            var commissionRates = Cosmos_Staking_V1beta1_CommissionRates()
            commissionRates.rate = NSDecimalNumber(string: validator["commission"]["commission_rates"]["rate"].string).multiplying(byPowerOf10: 18).stringValue
            commissionRates.maxRate = NSDecimalNumber(string: validator["commission"]["commission_rates"]["max_rate"].string).multiplying(byPowerOf10: 18).stringValue
            commissionRates.maxChangeRate = NSDecimalNumber(string: validator["commission"]["commission_rates"]["max_change_rate"].string).multiplying(byPowerOf10: 18).stringValue
            commission.commissionRates = commissionRates
            temp.commission = commission
            result.append(temp)
        })
        return result
    }
    
    func balances() -> [Cosmos_Base_V1beta1_Coin]? {
        var result = [Cosmos_Base_V1beta1_Coin]()
        self["balances"].array?.forEach({ coin in
            result.append(Cosmos_Base_V1beta1_Coin(coin["denom"].stringValue, coin["amount"].stringValue))
        })
        return result
    }
    
    func delegations() -> [Cosmos_Staking_V1beta1_DelegationResponse]? {
        var result = [Cosmos_Staking_V1beta1_DelegationResponse]()
        self["delegation_responses"].array?.forEach({ delegation in
            var temp = Cosmos_Staking_V1beta1_DelegationResponse()
            
            var staking = Cosmos_Staking_V1beta1_Delegation()
            staking.delegatorAddress = delegation["delegation"]["delegator_address"].stringValue
            staking.validatorAddress = delegation["delegation"]["validator_address"].stringValue
            staking.shares = NSDecimalNumber(string: delegation["delegation"]["shares"].stringValue).multiplying(byPowerOf10: 18).stringValue
            temp.delegation = staking
            
            let balance = Cosmos_Base_V1beta1_Coin(delegation["balance"]["denom"].stringValue, delegation["balance"]["amount"].stringValue)
            temp.balance = balance
            
            result.append(temp)
        })
        return result
    }
    
    func undelegations() -> [Cosmos_Staking_V1beta1_UnbondingDelegation]? {
        var result = [Cosmos_Staking_V1beta1_UnbondingDelegation]()
        self["unbonding_responses"].array?.forEach({ unbonding in
            var temp = Cosmos_Staking_V1beta1_UnbondingDelegation()
            temp.delegatorAddress = unbonding["delegator_address"].stringValue
            temp.validatorAddress = unbonding["validator_address"].stringValue
            
            var entries = [Cosmos_Staking_V1beta1_UnbondingDelegationEntry]()
            unbonding["entries"].array?.forEach({ entry in
                var tempEntry = Cosmos_Staking_V1beta1_UnbondingDelegationEntry()
                tempEntry.balance = entry["balance"].stringValue
                tempEntry.creationHeight = Int64(entry["creation_height"].stringValue) ?? 0
                //TODO for refact!!
                if let date = WDP.toDate(entry["completion_time"].stringValue) {
                    let time: Google_Protobuf_Timestamp = Google_Protobuf_Timestamp.init(timeIntervalSince1970: date.timeIntervalSince1970)
                    tempEntry.completionTime = time
                }
                
                entries.append(tempEntry)
            })
            temp.entries = entries
            
            result.append(temp)
        })
        return result
    }
    
    func rewards() -> [Cosmos_Distribution_V1beta1_DelegationDelegatorReward]? {
        var result = [Cosmos_Distribution_V1beta1_DelegationDelegatorReward]()
        self["rewards"].array?.forEach({ reward in
            var temp = Cosmos_Distribution_V1beta1_DelegationDelegatorReward()
            temp.validatorAddress = reward["validator_address"].stringValue
            
            var coins = [Cosmos_Base_V1beta1_DecCoin]()
            reward["reward"].array?.forEach({ rewardCoin in
                var tempDecoin = Cosmos_Base_V1beta1_DecCoin()
                tempDecoin.denom = rewardCoin["denom"].stringValue
                tempDecoin.amount = NSDecimalNumber(string: rewardCoin["amount"].stringValue).multiplying(byPowerOf10: 18).stringValue
                coins.append(tempDecoin)
            })
            temp.reward = coins
            
            result.append(temp)
        })
        return result
    }
    
    func commission() -> Cosmos_Distribution_V1beta1_ValidatorAccumulatedCommission? {
        var result = Cosmos_Distribution_V1beta1_ValidatorAccumulatedCommission()
        var coins = [Cosmos_Base_V1beta1_DecCoin]()
        self["commission"]["commission"].array?.forEach({ commission in
            var tempDecoin = Cosmos_Base_V1beta1_DecCoin()
            tempDecoin.denom = commission["denom"].stringValue
            tempDecoin.amount = NSDecimalNumber(string: commission["amount"].stringValue).multiplying(byPowerOf10: 18).stringValue
            coins.append(tempDecoin)
        })
        result.commission = coins
        return result
    }
    
    func rewardAddress() -> String? {
        return self["withdraw_address"].string
    }
    
    func feeMarket() -> [Cosmos_Base_V1beta1_DecCoin]? {
        var result = [Cosmos_Base_V1beta1_DecCoin]()
        self["prices"].array?.forEach({ coin in
            var tempDecoin = Cosmos_Base_V1beta1_DecCoin()
            tempDecoin.denom = coin["denom"].stringValue
            tempDecoin.amount = NSDecimalNumber(string: coin["amount"].stringValue).multiplying(byPowerOf10: 18).stringValue
            result.append(tempDecoin)
        })
        return result
    }
    
    func getAccountNum() -> UInt64 {
        if let result = self["account_number"].string {                                                         //BaseAccount
            return UInt64(result)!
        }
        if let result = self["base_vesting_account"]["base_account"]["account_number"].string {                 //PeriodicVestingAccount, ContinuousVestingAccount, DelayedVestingAccount
            return UInt64(result)!
        }
        if let result = self["base_account"]["account_number"].string {                                         //Injective_Types_V1beta1_EthAccount, Ethermint_Types_V1_EthAccount ,Artela_Types_V1_EthAccount
            return UInt64(result)!
        }
        if let result = self["account"]["base_vesting_account"]["base_account"]["account_number"].string {      //Desmos_Profiles_V3_Profile, vesting
            return UInt64(result)!
        }
        if let result = self["account"]["base_account"]["account_number"].string {                              //Desmos_Profiles_V3_Profile
            return UInt64(result)!
        }
        if let result = self["account"]["account_number"]["account_number"].string {                            //Desmos_Profiles_V3_Profile
            return UInt64(result)!
        }
        if let result = self["account"]["account_number"].string {                                              //Desmos_Profiles_V3_Profile
            return UInt64(result)!
        }
        return 0
    }
    
    
    func getSequenceNum() -> UInt64 {
        if let result = self["sequence"].string {                                                               //BaseAccount
            return UInt64(result)!
        }
        if let result = self["base_vesting_account"]["base_account"]["sequence"].string {                       //PeriodicVestingAccount, ContinuousVestingAccount, DelayedVestingAccount
            return UInt64(result)!
        }
        if let result = self["base_account"]["sequence"].string {                                               //Injective_Types_V1beta1_EthAccount, Ethermint_Types_V1_EthAccount ,Artela_Types_V1_EthAccount
            return UInt64(result)!
        }
        if let result = self["account"]["base_vesting_account"]["base_account"]["sequence"].string {            //Desmos_Profiles_V3_Profile, vesting
            return UInt64(result)!
        }
        if let result = self["account"]["base_account"]["sequence"].string {                                    //Desmos_Profiles_V3_Profile
            return UInt64(result)!
        }
        if let result = self["account"]["account_number"]["sequence"].string {                                  //Desmos_Profiles_V3_Profile
            return UInt64(result)!
        }
        if let result = self["account"]["sequence"].string {                                                    //Desmos_Profiles_V3_Profile
            return UInt64(result)!
        }
        return 0
    }
}


extension Google_Protobuf_Any {
    
    func accountInfos() -> (address: String?, accountNum: UInt64?, sequenceNum: UInt64?) {
        
        var rawAccount = self
        if (typeURL.contains(Desmos_Profiles_V3_Profile.protoMessageName)),
            let account = try? Desmos_Profiles_V3_Profile.init(serializedData: value).account {
            rawAccount = account
        }
        
        if (rawAccount.typeURL.contains(Cosmos_Auth_V1beta1_BaseAccount.protoMessageName)),
           let auth = try? Cosmos_Auth_V1beta1_BaseAccount.init(serializedData: rawAccount.value) {
            return (auth.address, auth.accountNumber, auth.sequence)

        } else if (rawAccount.typeURL.contains(Cosmos_Vesting_V1beta1_PeriodicVestingAccount.protoMessageName)),
                  let auth = try? Cosmos_Vesting_V1beta1_PeriodicVestingAccount.init(serializedData: rawAccount.value) {
            let baseAccount = auth.baseVestingAccount.baseAccount
            return (baseAccount.address, baseAccount.accountNumber, baseAccount.sequence)

        } else if (rawAccount.typeURL.contains(Cosmos_Vesting_V1beta1_ContinuousVestingAccount.protoMessageName)),
                  let auth = try? Cosmos_Vesting_V1beta1_ContinuousVestingAccount.init(serializedData: rawAccount.value) {
            let baseAccount = auth.baseVestingAccount.baseAccount
            return (baseAccount.address, baseAccount.accountNumber, baseAccount.sequence)

        } else if (rawAccount.typeURL.contains(Cosmos_Vesting_V1beta1_DelayedVestingAccount.protoMessageName)),
                  let auth = try? Cosmos_Vesting_V1beta1_DelayedVestingAccount.init(serializedData: rawAccount.value) {
            let baseAccount = auth.baseVestingAccount.baseAccount
            return (baseAccount.address, baseAccount.accountNumber, baseAccount.sequence)

        } else if (rawAccount.typeURL.contains(Stride_Vesting_StridePeriodicVestingAccount.protoMessageName)),
                  let auth = try? Stride_Vesting_StridePeriodicVestingAccount.init(serializedData: rawAccount.value) {
            let baseAccount = auth.baseVestingAccount.baseAccount
            return (baseAccount.address, baseAccount.accountNumber, baseAccount.sequence)

        } else if (rawAccount.typeURL.contains(Injective_Types_V1beta1_EthAccount.protoMessageName)),
                  let auth = try? Injective_Types_V1beta1_EthAccount.init(serializedData: rawAccount.value) {
            let baseAccount = auth.baseAccount
            return (baseAccount.address, baseAccount.accountNumber, baseAccount.sequence)

        } else if (rawAccount.typeURL.contains(Ethermint_Types_V1_EthAccount.protoMessageName)),
                    let auth = try? Ethermint_Types_V1_EthAccount.init(serializedData: rawAccount.value) {
            let baseAccount = auth.baseAccount
            return (baseAccount.address, baseAccount.accountNumber, baseAccount.sequence)

        } else if (rawAccount.typeURL.contains(Artela_Types_V1_EthAccount.protoMessageName)),
                  let auth = try? Artela_Types_V1_EthAccount.init(serializedData: rawAccount.value) {
            let baseAccount = auth.baseAccount
            return (baseAccount.address, baseAccount.accountNumber, baseAccount.sequence)
            
        } else if (rawAccount.typeURL.contains(Eth_Types_V1_EthAccount.protoMessageName)),
                  let auth = try? Eth_Types_V1_EthAccount.init(serializedData: rawAccount.value) {
            let baseAccount = auth.baseAccount
            return (baseAccount.address, baseAccount.accountNumber, baseAccount.sequence)

        }
        
        return (nil, nil, nil)
    }
    
}
