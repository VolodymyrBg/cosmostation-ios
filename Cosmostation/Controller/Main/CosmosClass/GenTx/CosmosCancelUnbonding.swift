//
//  CosmosCancelUnbonding.swift
//  Cosmostation
//
//  Created by yongjoo jung on 2023/11/06.
//  Copyright © 2023 wannabit. All rights reserved.
//

import UIKit
import Lottie
import SwiftProtobuf

class CosmosCancelUnbonding: BaseVC {
    
    @IBOutlet weak var titleCoinImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var validatorsLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountDenomLabel: UILabel!
    
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
    
    @IBOutlet weak var cancelBtn: BaseButton!
    @IBOutlet weak var loadingView: LottieAnimationView!
    
    var selectedChain: BaseChain!
    var cosmosFetcher: CosmosFetcher!
    var feeInfos = [FeeInfo]()
    var txFee: Cosmos_Tx_V1beta1_Fee = Cosmos_Tx_V1beta1_Fee.init()
    var txTip: Cosmos_Tx_V1beta1_Tip?
    var txMemo = ""
    var selectedFeePosition = 0
    
    var unbondingEntry: UnbondingEntry!
    var unbondingEntryInitia: InitiaUnbondingEntry!
    var unbondingEntryZenrock: ZenrockUnbondingEntry!

    var initiaFetcher: InitiaFetcher?
    var zenrockFetcher: ZenrockFetcher?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        baseAccount = BaseData.instance.baseAccount
        cosmosFetcher = selectedChain.getCosmosfetcher()
        initiaFetcher = (selectedChain as? ChainInitia)?.getInitiaFetcher()
        zenrockFetcher = (selectedChain as? ChainZenrock)?.getZenrockFetcher()

        loadingView.isHidden = false
        loadingView.animation = LottieAnimation.named("loading")
        loadingView.contentMode = .scaleAspectFit
        loadingView.loopMode = .loop
        loadingView.animationSpeed = 1.3
        loadingView.play()
        
        titleCoinImage.sd_setImage(with: selectedChain.assetImgUrl(selectedChain.stakingAssetDenom()), placeholderImage: UIImage(named: "tokenDefault"))
        
        if let initiaFetcher {
            if let validator = initiaFetcher.initiaValidators.filter({ $0.operatorAddress == unbondingEntryInitia.validatorAddress }).first  {
                validatorsLabel.text = validator.description_p.moniker
            }
            
            let stakeDenom = selectedChain.stakingAssetDenom()
            if let msAsset = BaseData.instance.getAsset(selectedChain.apiName, stakeDenom) {
                let unbondingAmount = NSDecimalNumber(string: unbondingEntryInitia.entry.balance.filter({ $0.denom == stakeDenom }).first?.amount).multiplying(byPowerOf10: -msAsset.decimals!)
                amountLabel.attributedText = WDP.dpAmount(unbondingAmount.stringValue, amountLabel.font, msAsset.decimals)
                amountDenomLabel.text = msAsset.symbol
            }
            
        } else if let zenrockFetcher {
            if let validator = zenrockFetcher.validators.filter({ $0.operatorAddress == unbondingEntryZenrock.validatorAddress }).first  {
                validatorsLabel.text = validator.description_p.moniker
            }
            
            let stakeDenom = selectedChain.stakingAssetDenom()
            if let msAsset = BaseData.instance.getAsset(selectedChain.apiName, stakeDenom) {
                let unbondingAmount = NSDecimalNumber(string: unbondingEntryZenrock.entry.balance).multiplying(byPowerOf10: -msAsset.decimals!)
                amountLabel.attributedText = WDP.dpAmount(unbondingAmount.stringValue, amountLabel.font, msAsset.decimals)
                amountDenomLabel.text = msAsset.symbol
            }

        } else {
            if let validator = cosmosFetcher.cosmosValidators.filter({ $0.operatorAddress == unbondingEntry.validatorAddress }).first {
                validatorsLabel.text = validator.description_p.moniker
            }
            
            let stakeDenom = selectedChain.stakingAssetDenom()
            if let msAsset = BaseData.instance.getAsset(selectedChain.apiName, stakeDenom) {
                let unbondingAmount = NSDecimalNumber(string: unbondingEntry.entry.balance).multiplying(byPowerOf10: -msAsset.decimals!)
                amountLabel?.attributedText = WDP.dpAmount(unbondingAmount.stringValue, amountLabel!.font, msAsset.decimals!)
                amountDenomLabel.text = msAsset.symbol
            }
        }
        
        feeSelectView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onSelectFeeCoin)))
        memoCardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickMemo)))
        
        Task {
            await cosmosFetcher.updateBaseFee()
            DispatchQueue.main.async {
                self.loadingView.isHidden = true
                self.oninitFeeView()
                self.onSimul()
            }
        }
    }
    
    override func setLocalizedString() {
        let symbol = selectedChain.assetSymbol(selectedChain.stakingAssetDenom())
        titleLabel.text = String(format: NSLocalizedString("title_coin_cancel_unstaking", comment: ""), symbol)
        memoHintLabel.text = NSLocalizedString("msg_tap_for_add_memo", comment: "")
        feeMsgLabel.text = NSLocalizedString("msg_about_fee_tip", comment: "")
        cancelBtn.setTitle(NSLocalizedString("str_cancle_unstake", comment: ""), for: .normal)
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
        cancelBtn.isEnabled = true
    }
    
    @IBAction func onClickCancel(_ sender: BaseButton) {
        let pinVC = UIStoryboard.PincodeVC(self, .ForDataCheck)
        self.present(pinVC, animated: true)
    }
    
    func onSimul() {
        view.isUserInteractionEnabled = false
        cancelBtn.isEnabled = false
        loadingView.isHidden = false
        
        if (selectedChain.isSimulable() == false) {
            return onUpdateWithSimul(nil)
        }
        
        Task {
            do {
                if let simulReq = try await Signer.genSimul(selectedChain, onBindCancelUnbondingMsg(), txMemo, txFee, nil),
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
    
    func onBindCancelUnbondingMsg() -> [Google_Protobuf_Any] {
        if selectedChain is ChainInitia {
            let toCoin = Cosmos_Base_V1beta1_Coin.with { coin in
                coin.denom = selectedChain.stakingAssetDenom()
                coin.amount = unbondingEntryInitia.entry.balance.filter({ $0.denom == selectedChain.stakingAssetDenom() }).first!.amount
            }
            
            let toCancelMsg = Initia_Mstaking_V1_MsgCancelUnbondingDelegation.with {
                $0.delegatorAddress = selectedChain.bechAddress!
                $0.validatorAddress = unbondingEntryInitia.validatorAddress
                $0.creationHeight = unbondingEntryInitia.entry.creationHeight
                $0.amount = [toCoin]
            }
            return Signer.genCancelUnbondingMsg(toCancelMsg)
            
        } else if selectedChain is ChainZenrock {
            let toCoin = Cosmos_Base_V1beta1_Coin.with { coin in
                coin.denom = selectedChain.stakingAssetDenom()
                coin.amount = unbondingEntryZenrock.entry.balance
            }
            
            let toCancelMsg = Zrchain_Validation_MsgCancelUnbondingDelegation.with {
                $0.delegatorAddress = selectedChain.bechAddress!
                $0.validatorAddress = unbondingEntryZenrock.validatorAddress
                $0.creationHeight = unbondingEntryZenrock.entry.creationHeight
                $0.amount = toCoin
            }
            return Signer.genCancelUnbondingMsg(toCancelMsg)
            
        } else if selectedChain is ChainBabylon {
            let toCoin = Cosmos_Base_V1beta1_Coin.with {  $0.denom = selectedChain.stakingAssetDenom(); $0.amount = unbondingEntry.entry.balance }
            let toCancelMsg = Babylon_Epoching_V1_MsgWrappedCancelUnbondingDelegation.with {
                $0.msg.delegatorAddress = selectedChain.bechAddress!
                $0.msg.validatorAddress = unbondingEntry.validatorAddress
                $0.msg.creationHeight = unbondingEntry.entry.creationHeight
                $0.msg.amount = toCoin
            }
            return Signer.genCancelUnbondingMsg(toCancelMsg)

        } else {
            let toCoin = Cosmos_Base_V1beta1_Coin.with {  $0.denom = selectedChain.stakingAssetDenom(); $0.amount = unbondingEntry.entry.balance }
            let toCancelMsg = Cosmos_Staking_V1beta1_MsgCancelUnbondingDelegation.with {
                $0.delegatorAddress = selectedChain.bechAddress!
                $0.validatorAddress = unbondingEntry.validatorAddress
                $0.creationHeight = unbondingEntry.entry.creationHeight
                $0.amount = toCoin
            }
            return Signer.genCancelUnbondingMsg(toCancelMsg)
        }
    }
}

extension CosmosCancelUnbonding: BaseSheetDelegate, MemoDelegate, PinDelegate {
    
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
            cancelBtn.isEnabled = false
            loadingView.isHidden = false
            Task {
                do {
                    if let broadReq = try await Signer.genTx(selectedChain, onBindCancelUnbondingMsg(), txMemo, txFee, nil),
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
