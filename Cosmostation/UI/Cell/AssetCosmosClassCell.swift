//
//  AssetCosmosClassCell.swift
//  Cosmostation
//
//  Created by yongjoo jung on 2023/08/21.
//  Copyright © 2023 wannabit. All rights reserved.
//

import UIKit
import SDWebImage

class AssetCosmosClassCell: UITableViewCell {
    
    @IBOutlet weak var rootView: CardViewCell!
    @IBOutlet weak var coinImg: CircleImageView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var priceCurrencyLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var priceChangePercentLabel: UILabel!
    @IBOutlet weak var valueCurrencyLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var hidenValueLabel: UILabel!
    
    @IBOutlet weak var availableTitle: UILabel!
    @IBOutlet weak var availableLabel: UILabel!
    @IBOutlet weak var vestingLayer: UIView!
    @IBOutlet weak var vestingTitle: UILabel!
    @IBOutlet weak var vestingLabel: UILabel!
    @IBOutlet weak var lockedLayer: UIView!
    @IBOutlet weak var lockedTitle: UILabel!
    @IBOutlet weak var lockedLabel: UILabel!
    @IBOutlet weak var stakingLayer: UIView!
    @IBOutlet weak var stakingTitle: UILabel!
    @IBOutlet weak var stakingLabel: UILabel!
    @IBOutlet weak var unstakingLayer: UIView!
    @IBOutlet weak var unstakingTitle: UILabel!
    @IBOutlet weak var unstakingLabel: UILabel!
    @IBOutlet weak var rewardLayer: UIView!
    @IBOutlet weak var rewardTitle: UILabel!
    @IBOutlet weak var rewardLabel: UILabel!
    @IBOutlet weak var vaultDepositedLayer: UIView!
    @IBOutlet weak var vaultDepositedLabel: UILabel!
    @IBOutlet weak var commissionLayer: UIView!
    @IBOutlet weak var commissionTitle: UILabel!
    @IBOutlet weak var commissionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        amountLabel.text = ""
        valueCurrencyLabel.text = ""
        valueLabel.text = ""
        amountLabel.isHidden = true
        valueCurrencyLabel.isHidden = true
        valueLabel.isHidden = true
        hidenValueLabel.isHidden = true
    }
    
    override func prepareForReuse() {
        coinImg.sd_cancelCurrentImageLoad()
        amountLabel.text = ""
        valueCurrencyLabel.text = ""
        valueLabel.text = ""
        amountLabel.isHidden = true
        valueCurrencyLabel.isHidden = true
        valueLabel.isHidden = true
        hidenValueLabel.isHidden = true
    }
    
    func bindCosmosStakeAsset(_ baseChain: BaseChain) {
        if let oktChain = baseChain as? ChainOktEVM {
            bindOktAsset(oktChain)
            
        } else if let neutronChain = baseChain as? ChainNeutron {
            bindNeutron(neutronChain)
            
        } else if let initiaChain = baseChain as? ChainInitia {
            bindInitia(initiaChain)
            
        } else if let zenrockChain = baseChain as? ChainZenrock {
            bindZenrock(zenrockChain)
            
        } else {
            let stakeDenom = baseChain.stakingAssetDenom()
            if let cosmosFetcher = baseChain.getCosmosfetcher(),
               let msAsset = BaseData.instance.getAsset(baseChain.apiName, stakeDenom) {
                let value = cosmosFetcher.denomValue(stakeDenom)
                
                coinImg.sd_setImage(with: msAsset.assetImg(), placeholderImage: UIImage(named: "tokenDefault"))
                symbolLabel.text = msAsset.symbol
                
                WDP.dpPrice(msAsset, priceCurrencyLabel, priceLabel)
                WDP.dpPriceChanged(msAsset, priceChangeLabel, priceChangePercentLabel)
                if (BaseData.instance.getHideValue()) {
                    hidenValueLabel.isHidden = false
                } else {
                    WDP.dpValue(value, valueCurrencyLabel, valueLabel)
                    amountLabel.isHidden = false
                    valueCurrencyLabel.isHidden = false
                    valueLabel.isHidden = false
                }
                
                let availableAmount = cosmosFetcher.availableAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
                availableLabel?.attributedText = WDP.dpAmount(availableAmount.stringValue, availableLabel!.font, 6)
                
                let lockedAmount = cosmosFetcher.lockedAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
                lockedLayer.isHidden = (lockedAmount == NSDecimalNumber.zero)
                lockedLabel?.attributedText = WDP.dpAmount(lockedAmount.stringValue, lockedLabel!.font, 6)
 
                let vestingAmount = cosmosFetcher.vestingAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
                vestingLayer.isHidden = (vestingAmount == NSDecimalNumber.zero)
                vestingLabel?.attributedText = WDP.dpAmount(vestingAmount.stringValue, vestingLabel!.font, 6)
                
                let stakingAmount = cosmosFetcher.delegationAmountSum().multiplying(byPowerOf10: -msAsset.decimals!)
                stakingLabel?.attributedText = WDP.dpAmount(stakingAmount.stringValue, stakingLabel!.font, 6)
                
                let unStakingAmount = cosmosFetcher.unbondingAmountSum().multiplying(byPowerOf10: -msAsset.decimals!)
                unstakingLabel?.attributedText = WDP.dpAmount(unStakingAmount.stringValue, unstakingLabel!.font, 6)
                
                let rewardAmount = cosmosFetcher.rewardAmountSum(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
                if (cosmosFetcher.rewardOtherDenomTypeCnts() > 0) {
                    rewardTitle.text = "Reward + " + String(cosmosFetcher.rewardOtherDenomTypeCnts())
                } else {
                    rewardTitle.text = "Reward"
                }
                rewardLabel?.attributedText = WDP.dpAmount(rewardAmount.stringValue, rewardLabel!.font, 6)
                
                let commissionAmount = cosmosFetcher.commissionAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
                if (cosmosFetcher.cosmosCommissions.count > 0) {
                    commissionLayer.isHidden = false
                    if (cosmosFetcher.commissionOtherDenoms() > 0) {
                        commissionTitle.text = "Commission + " + String(cosmosFetcher.commissionOtherDenoms())
                    } else {
                        commissionTitle.text = "Commission"
                    }
                    commissionLabel?.attributedText = WDP.dpAmount(commissionAmount.stringValue, commissionLabel!.font, 6)
                }
                
                let totalAmount = availableAmount.adding(lockedAmount).adding(vestingAmount).adding(stakingAmount)
                    .adding(unStakingAmount).adding(rewardAmount).adding(commissionAmount)
                amountLabel?.attributedText = WDP.dpAmount(totalAmount.stringValue, amountLabel!.font, 6)
                
                if (BaseData.instance.getHideValue()) {
                    availableLabel.text = "✱✱✱✱"
                    lockedLabel.text = "✱✱✱✱"
                    vestingLabel.text = "✱✱✱✱"
                    stakingLabel.text = "✱✱✱✱"
                    unstakingLabel.text = "✱✱✱✱"
                    rewardLabel.text = "✱✱✱✱"
                    commissionLabel.text = "✱✱✱✱"
                }
            }
        }
        
    }
    
    func bindOktAsset(_ oktChain: ChainOktEVM) {
        let stakeDenom = oktChain.stakingAssetDenom()
        if let oktFetcher = oktChain.getOktfetcher(),
           let msAsset = BaseData.instance.getAsset(oktChain.apiName, stakeDenom) {
            stakingTitle.text = "Deposited"
            unstakingTitle.text = "Withdrawing"
            
            let value = oktFetcher.allCoinValue()
            coinImg.sd_setImage(with: msAsset.assetImg(), placeholderImage: UIImage(named: "tokenDefault"))
            symbolLabel.text = msAsset.symbol?.uppercased()
            
            WDP.dpPrice(msAsset.coinGeckoId, priceCurrencyLabel, priceLabel)
            WDP.dpPriceChanged(msAsset.coinGeckoId, priceChangeLabel, priceChangePercentLabel)
            if (BaseData.instance.getHideValue()) {
                hidenValueLabel.isHidden = false
            } else {
                WDP.dpValue(value, valueCurrencyLabel, valueLabel)
                amountLabel.isHidden = false
                valueCurrencyLabel.isHidden = false
                valueLabel.isHidden = false
            }
            
            let availableAmount = oktFetcher.oktBalanceAmount(stakeDenom)
            availableLabel?.attributedText = WDP.dpAmount(availableAmount.stringValue, availableLabel!.font, 18)
            
            let depositAmount = oktFetcher.oktDepositAmount()
            stakingLabel?.attributedText = WDP.dpAmount(depositAmount.stringValue, stakingLabel!.font, 18)
            
            let withdrawAmount = oktFetcher.oktWithdrawAmount()
            if (withdrawAmount != NSDecimalNumber.zero) {
                unstakingLayer.isHidden = false
                unstakingLabel?.attributedText = WDP.dpAmount(withdrawAmount.stringValue, unstakingLabel!.font, 18)
            } else {
                unstakingLayer.isHidden = true
            }
            
            rewardLayer.isHidden = true
            
            let totalAmount = availableAmount.adding(depositAmount).adding(withdrawAmount)
            amountLabel?.attributedText = WDP.dpAmount(totalAmount.stringValue, amountLabel!.font, 18)
            
            if (BaseData.instance.getHideValue()) {
                availableLabel.text = "✱✱✱✱"
                stakingLabel.text = "✱✱✱✱"
                unstakingLabel.text = "✱✱✱✱"
            }
        }
    }
    
    func bindNeutron(_ baseChain: ChainNeutron) {
        let stakeDenom = baseChain.stakingAssetDenom()
        if let neutronFetcher = baseChain.getNeutronFetcher() {
            vaultDepositedLayer.isHidden = false
            if let msAsset = BaseData.instance.getAsset(baseChain.apiName, stakeDenom) {
                let value = neutronFetcher.denomValue(stakeDenom)
                coinImg.sd_setImage(with: msAsset.assetImg(), placeholderImage: UIImage(named: "tokenDefault"))
                symbolLabel.text = msAsset.symbol?.uppercased()
                
                WDP.dpPrice(msAsset, priceCurrencyLabel, priceLabel)
                WDP.dpPriceChanged(msAsset, priceChangeLabel, priceChangePercentLabel)
                if (BaseData.instance.getHideValue()) {
                    hidenValueLabel.isHidden = false
                } else {
                    WDP.dpValue(value, valueCurrencyLabel, valueLabel)
                    amountLabel.isHidden = false
                    valueCurrencyLabel.isHidden = false
                    valueLabel.isHidden = false
                }
                
                let availableAmount = neutronFetcher.balanceAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
                availableLabel?.attributedText = WDP.dpAmount(availableAmount.stringValue, availableLabel!.font, 6)
                
                let stakingAmount = neutronFetcher.delegationAmountSum().multiplying(byPowerOf10: -msAsset.decimals!)
                stakingLabel?.attributedText = WDP.dpAmount(stakingAmount.stringValue, stakingLabel!.font, 6)
                
                let unStakingAmount = neutronFetcher.unbondingAmountSum().multiplying(byPowerOf10: -msAsset.decimals!)
                unstakingLabel?.attributedText = WDP.dpAmount(unStakingAmount.stringValue, unstakingLabel!.font, 6)
                
                let rewardAmount = neutronFetcher.rewardAmountSum(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
                if (neutronFetcher.rewardOtherDenomTypeCnts() > 0) {
                    rewardTitle.text = "Reward + " + String(neutronFetcher.rewardOtherDenomTypeCnts())
                } else {
                    rewardTitle.text = "Reward"
                }
                
                rewardLabel?.attributedText = WDP.dpAmount(rewardAmount.stringValue, rewardLabel!.font, 6)
                
                let commissionAmount = neutronFetcher.commissionAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
                if (neutronFetcher.cosmosCommissions.count > 0) {
                    commissionLayer.isHidden = false
                    if (neutronFetcher.commissionOtherDenoms() > 0) {
                        commissionTitle.text = "Commission + " + String(neutronFetcher.commissionOtherDenoms())
                    } else {
                        commissionTitle.text = "Commission"
                    }
                    commissionLabel?.attributedText = WDP.dpAmount(commissionAmount.stringValue, commissionLabel!.font, 6)
                }
                
                let vestingAmount = neutronFetcher.neutronVestingAmount().multiplying(byPowerOf10: -msAsset.decimals!)
                if (vestingAmount != NSDecimalNumber.zero) {
                    vestingLayer.isHidden = false
                    vestingLabel?.attributedText = WDP.dpAmount(vestingAmount.stringValue, vestingLabel!.font, 6)
                }
                
                let depositedAmount = neutronFetcher.neutronDeposited.multiplying(byPowerOf10: -msAsset.decimals!)
                vaultDepositedLabel?.attributedText = WDP.dpAmount(depositedAmount.stringValue, vaultDepositedLabel!.font, 6)
                
                let totalAmount = availableAmount.adding(vestingAmount).adding(depositedAmount).adding(stakingAmount)
                    .adding(unStakingAmount).adding(rewardAmount).adding(commissionAmount)
                amountLabel?.attributedText = WDP.dpAmount(totalAmount.stringValue, amountLabel!.font, 6)
                
                if (BaseData.instance.getHideValue()) {
                    availableLabel.text = "✱✱✱✱"
                    vestingLabel.text = "✱✱✱✱"
                    stakingLabel.text = "✱✱✱✱"
                    unstakingLabel.text = "✱✱✱✱"
                    rewardLabel.text = "✱✱✱✱"
                    vaultDepositedLabel.text = "✱✱✱✱"
                }
            }
        }
    }
    
    func bindInitia(_ baseChain: ChainInitia)  {
        let stakeDenom = baseChain.stakingAssetDenom()
        if let initiaFetcher = baseChain.getInitiaFetcher(),
           let msAsset = BaseData.instance.getAsset(baseChain.apiName, stakeDenom) {
            let value = initiaFetcher.denomValue(stakeDenom)
            
            coinImg.sd_setImage(with: msAsset.assetImg(), placeholderImage: UIImage(named: "tokenDefault"))
            symbolLabel.text = msAsset.symbol?.uppercased()
            
            WDP.dpPrice(msAsset, priceCurrencyLabel, priceLabel)
            WDP.dpPriceChanged(msAsset, priceChangeLabel, priceChangePercentLabel)
            if (BaseData.instance.getHideValue()) {
                hidenValueLabel.isHidden = false
            } else {
                WDP.dpValue(value, valueCurrencyLabel, valueLabel)
                amountLabel.isHidden = false
                valueCurrencyLabel.isHidden = false
                valueLabel.isHidden = false
            }
            
            let availableAmount = initiaFetcher.balanceAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
            availableLabel?.attributedText = WDP.dpAmount(availableAmount.stringValue, availableLabel!.font, 6)
            
            let vestingAmount = initiaFetcher.vestingAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
            if (vestingAmount != NSDecimalNumber.zero) {
                vestingLayer.isHidden = false
                vestingLabel?.attributedText = WDP.dpAmount(vestingAmount.stringValue, vestingLabel!.font, 6)
            }
            
            
            let stakingAmount = initiaFetcher.initiaDelegationAmountSum().multiplying(byPowerOf10: -msAsset.decimals!)
            stakingLabel?.attributedText = WDP.dpAmount(stakingAmount.stringValue, stakingLabel!.font, 6)
            
            let unStakingAmount = initiaFetcher.initiaUnbondingAmountSum().multiplying(byPowerOf10: -msAsset.decimals!)
            unstakingLabel?.attributedText = WDP.dpAmount(unStakingAmount.stringValue, unstakingLabel!.font, 6)
            
            let rewardAmount = initiaFetcher.rewardAmountSum(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
            if (initiaFetcher.rewardOtherDenomTypeCnts() > 0) {
                rewardTitle.text = "Reward + " + String(initiaFetcher.rewardOtherDenomTypeCnts())
            } else {
                rewardTitle.text = "Reward"
            }
            rewardLabel?.attributedText = WDP.dpAmount(rewardAmount.stringValue, rewardLabel!.font, 6)
            
            let commissionAmount = initiaFetcher.commissionAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
            if (initiaFetcher.cosmosCommissions.count > 0) {
                commissionLayer.isHidden = false
                if (initiaFetcher.commissionOtherDenoms() > 0) {
                    commissionTitle.text = "Commission + " + String(initiaFetcher.commissionOtherDenoms())
                } else {
                    commissionTitle.text = "Commission"
                }
                commissionLabel?.attributedText = WDP.dpAmount(commissionAmount.stringValue, commissionLabel!.font, 6)
            }
            
            let totalAmount = availableAmount.adding(vestingAmount).adding(stakingAmount)
                .adding(unStakingAmount).adding(rewardAmount).adding(commissionAmount)
            amountLabel?.attributedText = WDP.dpAmount(totalAmount.stringValue, amountLabel!.font, 6)
            
            if (BaseData.instance.getHideValue()) {
                availableLabel.text = "✱✱✱✱"
                vestingLabel.text = "✱✱✱✱"
                stakingLabel.text = "✱✱✱✱"
                unstakingLabel.text = "✱✱✱✱"
                rewardLabel.text = "✱✱✱✱"
                commissionLabel.text = "✱✱✱✱"
            }
        }
    }
    
    func bindZenrock(_ baseChain: ChainZenrock) {
        let stakeDenom = baseChain.stakingAssetDenom()
        if let zenrockFetcher = baseChain.getZenrockFetcher(),
           let msAsset = BaseData.instance.getAsset(baseChain.apiName, stakeDenom) {
            let value = zenrockFetcher.denomValue(stakeDenom)
            
            coinImg.sd_setImage(with: msAsset.assetImg(), placeholderImage: UIImage(named: "tokenDefault"))
            symbolLabel.text = msAsset.symbol?.uppercased()
            
            WDP.dpPrice(msAsset, priceCurrencyLabel, priceLabel)
            WDP.dpPriceChanged(msAsset, priceChangeLabel, priceChangePercentLabel)
            if (BaseData.instance.getHideValue()) {
                hidenValueLabel.isHidden = false
            } else {
                WDP.dpValue(value, valueCurrencyLabel, valueLabel)
                amountLabel.isHidden = false
                valueCurrencyLabel.isHidden = false
                valueLabel.isHidden = false
            }
            
            let availableAmount = zenrockFetcher.balanceAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
            availableLabel?.attributedText = WDP.dpAmount(availableAmount.stringValue, availableLabel!.font, 6)
            
            let vestingAmount = zenrockFetcher.vestingAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
            if (vestingAmount != NSDecimalNumber.zero) {
                vestingLayer.isHidden = false
                vestingLabel?.attributedText = WDP.dpAmount(vestingAmount.stringValue, vestingLabel!.font, 6)
            }
            
            
            let stakingAmount = zenrockFetcher.zenrockDelegationAmountSum().multiplying(byPowerOf10: -msAsset.decimals!)
            stakingLabel?.attributedText = WDP.dpAmount(stakingAmount.stringValue, stakingLabel!.font, 6)
            
            let unStakingAmount = zenrockFetcher.zenrockUnbondingAmountSum().multiplying(byPowerOf10: -msAsset.decimals!)
            unstakingLabel?.attributedText = WDP.dpAmount(unStakingAmount.stringValue, unstakingLabel!.font, 6)
            
            let rewardAmount = zenrockFetcher.rewardAmountSum(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
            if (zenrockFetcher.rewardOtherDenomTypeCnts() > 0) {
                rewardTitle.text = "Reward + " + String(zenrockFetcher.rewardOtherDenomTypeCnts())
            } else {
                rewardTitle.text = "Reward"
            }
            rewardLabel?.attributedText = WDP.dpAmount(rewardAmount.stringValue, rewardLabel!.font, 6)
            
            let commissionAmount = zenrockFetcher.commissionAmount(stakeDenom).multiplying(byPowerOf10: -msAsset.decimals!)
            if (zenrockFetcher.cosmosCommissions.count > 0) {
                commissionLayer.isHidden = false
                if (zenrockFetcher.commissionOtherDenoms() > 0) {
                    commissionTitle.text = "Commission + " + String(zenrockFetcher.commissionOtherDenoms())
                } else {
                    commissionTitle.text = "Commission"
                }
                commissionLabel?.attributedText = WDP.dpAmount(commissionAmount.stringValue, commissionLabel!.font, 6)
            }
            
            let totalAmount = availableAmount.adding(vestingAmount).adding(stakingAmount)
                .adding(unStakingAmount).adding(rewardAmount).adding(commissionAmount)
            amountLabel?.attributedText = WDP.dpAmount(totalAmount.stringValue, amountLabel!.font, 6)
            
            if (BaseData.instance.getHideValue()) {
                availableLabel.text = "✱✱✱✱"
                vestingLabel.text = "✱✱✱✱"
                stakingLabel.text = "✱✱✱✱"
                unstakingLabel.text = "✱✱✱✱"
                rewardLabel.text = "✱✱✱✱"
                commissionLabel.text = "✱✱✱✱"
            }
        }
    }
}
