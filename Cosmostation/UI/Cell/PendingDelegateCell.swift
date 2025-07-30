//
//  PendingDelegateCell.swift
//  Cosmostation
//
//  Created by 차소민 on 3/11/25.
//  Copyright © 2025 wannabit. All rights reserved.
//

import UIKit

class PendingDelegateCell: UITableViewCell {
    @IBOutlet weak var rootView: CardViewCell!
    @IBOutlet weak var logoImg: UIImageView!
    @IBOutlet weak var inactiveTag: UIImageView!
    @IBOutlet weak var jailedTag: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var commTitle: UILabel!
    @IBOutlet weak var commLabel: UILabel!
    @IBOutlet weak var commPercentLabel: UILabel!
    @IBOutlet weak var stakingTitle: UILabel!
    @IBOutlet weak var stakingLabel: UILabel!
    @IBOutlet weak var rewardTitle: UILabel!
    @IBOutlet weak var rewardLabel: UILabel!
    @IBOutlet weak var estTitleLabel: UILabel!
    @IBOutlet weak var estLabel: UILabel!
    @IBOutlet weak var pendingInfoLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    override func prepareForReuse() {
        logoImg.sd_cancelCurrentImageLoad()
        logoImg.image = UIImage(named: "iconValidatorDefault")
        jailedTag.isHidden = true
        inactiveTag.isHidden = true
    }
    
    func onBindMyDelegate(_ baseChain: BaseChain, _ validator: Cosmos_Staking_V1beta1_Validator, _ pendingData: PendingTx, _ epoch: UInt64?) {
        
        if let statusStr = pendingData.type_url?.status,
           let epoch {
            pendingInfoLabel.text = "\(statusStr) will activate in Next Epoch #\(epoch + 1)"
        }
        
        logoImg.sd_setImage(with: baseChain.monikerImg(validator.operatorAddress), placeholderImage: UIImage(named: "iconValidatorDefault"))
        nameLabel.text = validator.description_p.moniker
            
        guard let cosmosFetcher = baseChain.getCosmosfetcher() else { return }
        
        if (validator.jailed) {
            jailedTag.isHidden = false
        } else {
            inactiveTag.isHidden = cosmosFetcher.isActiveValidator(validator)
        }
        if let stakeDenom = baseChain.stakeDenom,
           let msAsset = BaseData.instance.getAsset(baseChain.apiName, stakeDenom) {
            let vpAmount = NSDecimalNumber(string: validator.tokens).multiplying(byPowerOf10: -msAsset.decimals!)
            
            let commission = NSDecimalNumber(string: validator.commission.commissionRates.rate).multiplying(byPowerOf10: -16)
            commLabel?.attributedText = WDP.dpAmount(commission.stringValue, commLabel!.font, 2)
            
            let stakedAmount = NSDecimalNumber(string: pendingData.msg.amount).multiplying(byPowerOf10: -msAsset.decimals!)
            stakingLabel?.attributedText = WDP.dpAmount(stakedAmount.stringValue, stakingLabel!.font, msAsset.decimals!)
            
            rewardLabel?.attributedText = WDP.dpAmount("0", rewardLabel!.font, msAsset.decimals!)
            rewardTitle.text = "Reward"
            
            
            //Display monthly est reward amount
            let apr = NSDecimalNumber(string: baseChain.getChainParam()["params"]["apr"].string ?? "0")
            let staked = NSDecimalNumber(string: pendingData.msg.amount)
            let comm = NSDecimalNumber.one.subtracting(NSDecimalNumber(string: validator.commission.commissionRates.rate).multiplying(byPowerOf10: -18))
            let est = staked.multiplying(by: apr).multiplying(by: comm, withBehavior: handler0).dividing(by: NSDecimalNumber.init(string: "12"), withBehavior: handler0).multiplying(byPowerOf10: -msAsset.decimals!)
            estLabel?.attributedText = WDP.dpAmount(est.stringValue, estLabel!.font, msAsset.decimals!)
        }

    }
}
