//
//  BabylonClaimRewards.swift
//  Cosmostation
//
//  Created by 차소민 on 3/5/25.
//  Copyright © 2025 wannabit. All rights reserved.
//

import UIKit
import Lottie
import SwiftProtobuf

class BabylonClaimRewards: BaseVC {
    @IBOutlet weak var titleCoinImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var totalRewardAmountLabel: UILabel!
    @IBOutlet weak var totalRewardDenomLabel: UILabel!
    @IBOutlet weak var rewardAmountLabel: UILabel!
    @IBOutlet weak var rewardDenomLabel: UILabel!
    @IBOutlet weak var rewardCntLabel: UILabel!
    @IBOutlet weak var btcRewardAmountLabel: UILabel!
    @IBOutlet weak var btcRewardDenomLabel: UILabel!
    @IBOutlet weak var btcRewardCntLabel: UILabel!
    
    @IBOutlet weak var memoCardView: FixCardView!
    @IBOutlet weak var memoTitle: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var memoHintLabel: UILabel!
    
    @IBOutlet weak var feeSelectView: DropDownView!
    @IBOutlet weak var feeMsgLabel: UILabel!
    @IBOutlet weak var feeSelectImg: UIImageView!
    @IBOutlet weak var feeSelectLabel: UILabel!
    @IBOutlet weak var feeAmountLabel: UILabel!
    @IBOutlet weak var feeDenomLabel: UILabel!
    @IBOutlet weak var feeCurrencyLabel: UILabel!
    @IBOutlet weak var feeValueLabel: UILabel!
    @IBOutlet weak var feeSegments: UISegmentedControl!
    
    @IBOutlet weak var claimBtn: BaseButton!
    @IBOutlet weak var loadingView: LottieAnimationView!
    
    var selectedChain: ChainBabylon!
    var cosmosFetcher: CosmosFetcher!
    var babylonBtcFetcher: BabylonBTCFetcher!
    
    var claimableRewards = [Cosmos_Distribution_V1beta1_DelegationDelegatorReward]()
    var feeInfos = [FeeInfo]()
    var txFee: Cosmos_Tx_V1beta1_Fee = Cosmos_Tx_V1beta1_Fee.init()
    var txTip: Cosmos_Tx_V1beta1_Tip?
    var txMemo = ""
    var selectedFeePosition = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        baseAccount = BaseData.instance.baseAccount
        cosmosFetcher = selectedChain.getCosmosfetcher()
        babylonBtcFetcher = selectedChain.getBabylonBtcFetcher()
        
        claimableRewards = cosmosFetcher.claimableRewards()
        
        loadingView.isHidden = false
        loadingView.animation = LottieAnimation.named("loading")
        loadingView.contentMode = .scaleAspectFit
        loadingView.loopMode = .loop
        loadingView.animationSpeed = 1.3
        loadingView.play()

        feeSelectView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onSelectFeeCoin)))
        memoCardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickMemo)))
        
        Task {
            await cosmosFetcher.updateBaseFee()
            DispatchQueue.main.async {
                self.loadingView.isHidden = true
                self.onInitView()
                self.oninitFeeView()
                self.onSimul()
            }
        }
        
        

    }

    override func setLocalizedString() {
        memoHintLabel.text = NSLocalizedString("msg_tap_for_add_memo", comment: "")
        feeMsgLabel.text = NSLocalizedString("msg_about_fee_tip", comment: "")
        claimBtn.setTitle(NSLocalizedString("tx_get_reward", comment: ""), for: .normal)
    }
    

    func onInitView() {
        let stakeDenom = selectedChain.stakingAssetDenom()
        if let msAsset = BaseData.instance.getAsset(selectedChain.apiName, stakeDenom) {
            var rewardAmount = NSDecimalNumber.zero
            claimableRewards.forEach { reward in
                let rawAmount =  NSDecimalNumber(string: reward.reward.filter{ $0.denom == stakeDenom }.first?.amount ?? "0")
                rewardAmount = rewardAmount.adding(rawAmount.multiplying(byPowerOf10: -18, withBehavior: handler0Down))
            }
            
            WDP.dpCoin(msAsset, rewardAmount, nil, rewardDenomLabel, rewardAmountLabel, msAsset.decimals)

            var btcRewardAmount = NSDecimalNumber.zero
            let rawAmount =  NSDecimalNumber(string: babylonBtcFetcher.btcStakedRewards.filter{ $0.denom == stakeDenom }.first?.amount ?? "0")
            btcRewardAmount = btcRewardAmount.adding(rawAmount)
            
            WDP.dpCoin(msAsset, btcRewardAmount, nil, btcRewardDenomLabel, btcRewardAmountLabel, msAsset.decimals)
            
            let totalRewardAmount = rewardAmount.adding(btcRewardAmount)
            WDP.dpCoin(msAsset, totalRewardAmount, nil, totalRewardDenomLabel, totalRewardAmountLabel, msAsset.decimals)
        }
        
        
        var anotherRewardDenom = Array<String>()
        claimableRewards.forEach { reward in
            reward.reward.filter { $0.denom != stakeDenom }.forEach { anotherRewards in
                let anotherAmount = NSDecimalNumber(string: anotherRewards.amount).multiplying(byPowerOf10: -18, withBehavior: handler0Down)
                if (anotherAmount != NSDecimalNumber.zero) {
                    if (!anotherRewardDenom.contains(anotherRewards.denom)) {
                        anotherRewardDenom.append(anotherRewards.denom)
                    }
                }
            }
        }
        if (anotherRewardDenom.count > 0) {
            rewardCntLabel.isHidden = false
            rewardCntLabel.text = "+ " + String(anotherRewardDenom.count)
            titleCoinImage.isHidden = true
            titleLabel.text = NSLocalizedString("str_cliam_reward", comment: "")
        } else {
            rewardCntLabel.isHidden = true
            titleCoinImage.isHidden = false
            let symbol = selectedChain.assetSymbol(selectedChain.stakingAssetDenom())
            titleLabel.text = String(format: NSLocalizedString("title_coin_rewards_claim", comment: ""), symbol)
            titleCoinImage.sd_setImage(with: selectedChain.assetImgUrl(selectedChain.stakingAssetDenom()), placeholderImage: UIImage(named: "tokenDefault"))
        }

        // BtcRewards anotherDenom
        var anotherBtcRewardDenom = Array<String>()
        babylonBtcFetcher.btcStakedRewards.filter { $0.denom != stakeDenom }.forEach { anotherRewards in
            let anotherAmount = NSDecimalNumber(string: anotherRewards.amount).multiplying(byPowerOf10: -18, withBehavior: handler0Down)
            if (anotherAmount != NSDecimalNumber.zero) {
                if (!anotherBtcRewardDenom.contains(anotherRewards.denom)) {
                    anotherBtcRewardDenom.append(anotherRewards.denom)
                }
            }
        }
        if (anotherBtcRewardDenom.count > 0) {
            btcRewardCntLabel.isEnabled = false
            btcRewardCntLabel.text = "+ " + String(anotherBtcRewardDenom.count)
            titleCoinImage.isHidden = true
            titleLabel.text = NSLocalizedString("str_cliam_reward", comment: "")
        } else {
            btcRewardCntLabel.isHidden = true
            titleCoinImage.isHidden = false
            let symbol = selectedChain.assetSymbol(selectedChain.stakingAssetDenom() ?? "")
            titleLabel.text = String(format: NSLocalizedString("title_coin_rewards_claim", comment: ""), symbol)
            titleCoinImage.sd_setImage(with: selectedChain.assetImgUrl(selectedChain.stakingAssetDenom() ?? ""), placeholderImage: UIImage(named: "tokenDefault"))
        }
    }
    
    func oninitFeeView() {
        if (cosmosFetcher.cosmosBaseFees.count > 0) {
            feeSegments.removeAllSegments()
            feeSegments.insertSegment(withTitle: "Default", at: 0, animated: false)
            feeSegments.insertSegment(withTitle: "Fast", at: 1, animated: false)
            feeSegments.insertSegment(withTitle: "Faster", at: 2, animated: false)
            feeSegments.insertSegment(withTitle: "Instant", at: 3, animated: false)
            feeSegments.selectedSegmentIndex = selectedFeePosition
            
            let baseFee = cosmosFetcher.cosmosBaseFees[0]
            let gasAmount: NSDecimalNumber = selectedChain.getInitGasLimit()
            let feeDenom = baseFee.denom
            let feeAmount = baseFee.getdAmount().multiplying(by: gasAmount, withBehavior: handler0Down)
            txFee.gasLimit = gasAmount.uint64Value
            txFee.amount = [Cosmos_Base_V1beta1_Coin(feeDenom, feeAmount)]
            
        } else {
            feeInfos = selectedChain.getFeeInfos()
            feeSegments.removeAllSegments()
            for i in 0..<feeInfos.count {
                feeSegments.insertSegment(withTitle: feeInfos[i].title, at: i, animated: false)
            }
            selectedFeePosition = selectedChain.getBaseFeePosition()
            feeSegments.selectedSegmentIndex = selectedFeePosition
            txFee = selectedChain.getInitPayableFee()!
        }
        onUpdateFeeView()
    }
    
    @objc func onSelectFeeCoin() {
        let baseSheet = BaseSheet(nibName: "BaseSheet", bundle: nil)
        baseSheet.targetChain = selectedChain
        baseSheet.sheetDelegate = self
        if (cosmosFetcher.cosmosBaseFees.count > 0) {
            baseSheet.baseFeesDatas = cosmosFetcher.cosmosBaseFees
            baseSheet.sheetType = .SelectBaseFeeDenom
        } else {
            baseSheet.feeDatas = feeInfos[selectedFeePosition].FeeDatas
            baseSheet.sheetType = .SelectFeeDenom
        }
        onStartSheet(baseSheet, 240, 0.6)
    }
    
    @IBAction func feeSegmentSelected(_ sender: UISegmentedControl) {
        selectedFeePosition = sender.selectedSegmentIndex
        if (cosmosFetcher.cosmosBaseFees.count > 0) {
            if let baseFee = cosmosFetcher.cosmosBaseFees.filter({ $0.denom == txFee.amount[0].denom }).first {
                let gasLimit = NSDecimalNumber.init(value: txFee.gasLimit)
                let feeAmount = baseFee.getdAmount().multiplying(by: gasLimit, withBehavior: handler0Up)
                txFee.amount[0].amount = feeAmount.stringValue
                txFee = Signer.setFee(selectedFeePosition, txFee)
            }
            
        } else {
            txFee = selectedChain.getUserSelectedFee(selectedFeePosition, txFee.amount[0].denom)
        }
        onUpdateFeeView()
        onSimul()
    }
    
    func onUpdateFeeView() {
        if let msAsset = BaseData.instance.getAsset(selectedChain.apiName, txFee.amount[0].denom) {
            feeSelectLabel.text = msAsset.symbol
            
            let totalFeeAmount = NSDecimalNumber(string: txFee.amount[0].amount)
            let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId)
            let value = msPrice.multiplying(by: totalFeeAmount).multiplying(byPowerOf10: -msAsset.decimals!, withBehavior: handler6)
            WDP.dpCoin(msAsset, totalFeeAmount, feeSelectImg, feeDenomLabel, feeAmountLabel, msAsset.decimals)
            WDP.dpValue(value, feeCurrencyLabel, feeValueLabel)
        }
    }
    
    @objc func onClickMemo() {
        let memoSheet = TxMemoSheet(nibName: "TxMemoSheet", bundle: nil)
        memoSheet.existedMemo = txMemo
        memoSheet.memoDelegate = self
        onStartSheet(memoSheet, 260, 0.6)
    }
    
    func onUpdateMemoView(_ memo: String) {
        txMemo = memo
        if (txMemo.isEmpty) {
            memoLabel.isHidden = true
            memoHintLabel.isHidden = false
        } else {
            memoLabel.text = txMemo
            memoLabel.isHidden = false
            memoHintLabel.isHidden = true
        }
        onSimul()
    }
    
    func onUpdateWithSimul(_ gasUsed: UInt64?) {
        if let toGas = gasUsed {
            txFee.gasLimit = UInt64(Double(toGas) * selectedChain.getSimulatedGasMultiply())
            if (cosmosFetcher.cosmosBaseFees.count > 0) {
                if let baseFee = cosmosFetcher.cosmosBaseFees.filter({ $0.denom == txFee.amount[0].denom }).first {
                    let gasLimit = NSDecimalNumber.init(value: txFee.gasLimit)
                    let feeAmount = baseFee.getdAmount().multiplying(by: gasLimit, withBehavior: handler0Up)
                    txFee.amount[0].amount = feeAmount.stringValue
                    txFee = Signer.setFee(selectedFeePosition, txFee)
                }
                
            } else {
                if let gasRate = feeInfos[selectedFeePosition].FeeDatas.filter({ $0.denom == txFee.amount[0].denom }).first {
                    let gasLimit = NSDecimalNumber.init(value: txFee.gasLimit)
                    let feeAmount = gasRate.gasRate?.multiplying(by: gasLimit, withBehavior: handler0Up)
                    txFee.amount[0].amount = feeAmount!.stringValue
                }
            }
        }
        onUpdateFeeView()
        view.isUserInteractionEnabled = true
        loadingView.isHidden = true
        claimBtn.isEnabled = true
    }
    
    @IBAction func onClickClaim(_ sender: BaseButton) {
        let pinVC = UIStoryboard.PincodeVC(self, .ForDataCheck)
        self.present(pinVC, animated: true)
    }
    
    func onSimul() {
        view.isUserInteractionEnabled = false
        claimBtn.isEnabled = false
        loadingView.isHidden = false
        if (selectedChain.isSimulable() == false) {
            return onUpdateWithSimul(nil)
        }
        
        Task {
            do {
                if let simulReq = try await Signer.genSimul(selectedChain, onBindRewardMsgs(), txMemo, txFee, nil),
                   let simulRes = try await cosmosFetcher.simulateTx(simulReq) {
                    DispatchQueue.main.async {
                        self.onUpdateWithSimul(simulRes)
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.view.isUserInteractionEnabled = true
                    self.loadingView.isHidden = true
                    self.onShowToast("Error : " + "\n" + "\(error)")
                    return
                }
            }
        }
    }
    
    func onBindRewardMsgs() -> [Google_Protobuf_Any] {
        return Signer.genBabylonClaimStakingRewardMsg(selectedChain.bechAddress!, claimableRewards)
    }

}
extension BabylonClaimRewards: MemoDelegate, BaseSheetDelegate, PinDelegate {
    
    func onSelectedSheet(_ sheetType: SheetType?, _ result: Dictionary<String, Any>) {
        if (sheetType == .SelectFeeDenom) {
            if let index = result["index"] as? Int,
               let selectedDenom = feeInfos[selectedFeePosition].FeeDatas[index].denom {
                txFee = selectedChain.getUserSelectedFee(selectedFeePosition, selectedDenom)
                onUpdateFeeView()
                onSimul()
            }
            
        } else if (sheetType == .SelectBaseFeeDenom) {
            if let index = result["index"] as? Int {
               let selectedDenom = cosmosFetcher.cosmosBaseFees[index].denom
                txFee.amount[0].denom = selectedDenom
                onUpdateFeeView()
                onSimul()
            }
        }
    }
    
    func onInputedMemo(_ memo: String) {
        onUpdateMemoView(memo)
    }
    
    func onPinResponse(_ request: LockType, _ result: UnLockResult) {
        if (result == .success) {
            view.isUserInteractionEnabled = false
            claimBtn.isEnabled = false
            loadingView.isHidden = false
            Task {
                do {
                    if let broadReq = try await Signer.genTx(selectedChain, onBindRewardMsgs(), txMemo, txFee, nil),
                       let broadRes = try await cosmosFetcher.broadcastTx(broadReq) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000), execute: {
                            self.loadingView.isHidden = true
                            let txResult = CosmosTxResult(nibName: "CosmosTxResult", bundle: nil)
                            txResult.selectedChain = self.selectedChain
                            txResult.broadcastTxResponse = broadRes
                            txResult.modalPresentationStyle = .fullScreen
                            self.present(txResult, animated: true)
                        })
                    }
                    
                } catch {
                    //TODO handle Error
                }
            }
        }
    }
}
