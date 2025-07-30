//
//  CosmosRedelegate.swift
//  Cosmostation
//
//  Created by yongjoo jung on 2023/10/01.
//  Copyright © 2023 wannabit. All rights reserved.
//

import UIKit
import Lottie
import SwiftProtobuf
import SDWebImage

class CosmosRedelegate: BaseVC {
    
    @IBOutlet weak var titleCoinImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var fromCardView: FixCardView!
    @IBOutlet weak var fromMonikerImg: UIImageView!
    @IBOutlet weak var fromInactiveTag: UIImageView!
    @IBOutlet weak var fromJailedTag: UIImageView!
    @IBOutlet weak var fromMonikerLabel: UILabel!
    @IBOutlet weak var fromStakedLabel: UILabel!
    
    @IBOutlet weak var toCardView: FixCardView!
    @IBOutlet weak var toMonikerImg: UIImageView!
    @IBOutlet weak var toInactiveTag: UIImageView!
    @IBOutlet weak var toJailedTag: UIImageView!
    @IBOutlet weak var toMonikerLabel: UILabel!
    @IBOutlet weak var toCommLabel: UILabel!
    @IBOutlet weak var toCommPercentLabel: UILabel!
    
    @IBOutlet weak var amountCardView: FixCardView!
    @IBOutlet weak var amountTitle: UILabel!
    @IBOutlet weak var amountHintLabel: UILabel!
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
    
    @IBOutlet weak var reStakeBtn: BaseButton!
    @IBOutlet weak var loadingView: LottieAnimationView!
    
    var selectedChain: BaseChain!
    var cosmosFetcher: CosmosFetcher!
    var feeInfos = [FeeInfo]()
    var txFee: Cosmos_Tx_V1beta1_Fee = Cosmos_Tx_V1beta1_Fee.init()
    var txTip: Cosmos_Tx_V1beta1_Tip?
    var txMemo = ""
    var selectedFeePosition = 0
    
    var availableAmount = NSDecimalNumber.zero
    var fromValidator: Cosmos_Staking_V1beta1_Validator?
    var toValidator: Cosmos_Staking_V1beta1_Validator?
    var toCoin: Cosmos_Base_V1beta1_Coin?

    var fromValidatorInitia: Initia_Mstaking_V1_Validator?
    var toValidatorInitia: Initia_Mstaking_V1_Validator?
    var initiaFetcher: InitiaFetcher?
    
    var fromValidatorZenrock: Zrchain_Validation_ValidatorHV?
    var toValidatorZenrock: Zrchain_Validation_ValidatorHV?
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
        
        titleCoinImage.sd_setImage(with: selectedChain.assetImgUrl(selectedChain.stakeDenom ?? ""), placeholderImage: UIImage(named: "tokenDefault"))

        fromCardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickFromValidator)))
        toCardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickToValidator)))
        amountCardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickAmount)))
        feeSelectView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onSelectFeeCoin)))
        memoCardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickMemo)))
        
        if let initiaFetcher {
            if fromValidatorInitia == nil {
                fromValidatorInitia = initiaFetcher.initiaValidators.filter({ $0.operatorAddress == initiaFetcher.initiaDelegations[0].delegation.validatorAddress }).first
            }
            
            let cosmostation = initiaFetcher.initiaValidators.filter({ $0.description_p.moniker == "Cosmostation" }).first
            if (fromValidatorInitia?.operatorAddress == cosmostation?.operatorAddress) {
                toValidatorInitia = initiaFetcher.initiaValidators.filter( { $0.operatorAddress != cosmostation?.operatorAddress }).first
            } else {
                toValidatorInitia = initiaFetcher.initiaValidators.filter( { $0.operatorAddress != fromValidatorInitia?.operatorAddress }).first
            }
            
        } else if let zenrockFetcher {
            if fromValidatorZenrock == nil {
                fromValidatorZenrock = zenrockFetcher.validators.filter({ $0.operatorAddress == zenrockFetcher.delegations[0].delegation.validatorAddress }).first
            }
            
            let cosmostation = zenrockFetcher.validators.filter({ $0.description_p.moniker == "Cosmostation" }).first
            if (fromValidatorZenrock?.operatorAddress == cosmostation?.operatorAddress) {
                toValidatorZenrock = zenrockFetcher.validators.filter( { $0.operatorAddress != cosmostation?.operatorAddress }).first
            } else {
                toValidatorZenrock = zenrockFetcher.validators.filter( { $0.operatorAddress != fromValidatorZenrock?.operatorAddress }).first
            }
            
        } else {
            if (fromValidator == nil) {
                fromValidator = cosmosFetcher.cosmosValidators.filter { $0.operatorAddress == cosmosFetcher.cosmosDelegations[0].delegation.validatorAddress }.first
            }
            
            let cosmostation = cosmosFetcher.cosmosValidators.filter({ $0.description_p.moniker == "Cosmostation" }).first
            if (fromValidator?.operatorAddress == cosmostation?.operatorAddress) {
                toValidator = cosmosFetcher.cosmosValidators.filter({ $0.operatorAddress != cosmostation!.operatorAddress }).first
            } else {
                toValidator = cosmosFetcher.cosmosValidators.filter({ $0.operatorAddress != fromValidator?.operatorAddress }).first
            }
        }
        
        
        Task {
            await cosmosFetcher.updateBaseFee()
            DispatchQueue.main.async {
                self.loadingView.isHidden = true
                self.onUpdateFromValidatorView()
                self.onUpdateToValidatorView()
                self.oninitFeeView()
            }
        }
    }
    
    override func setLocalizedString() {
        let symbol = selectedChain.assetSymbol(selectedChain.stakeDenom ?? "")
        titleLabel.text = String(format: NSLocalizedString("title_coin_switch_validator", comment: ""), symbol)
        amountTitle.text = NSLocalizedString("str_redelegate_amount", comment: "")
        amountHintLabel.text = NSLocalizedString("msg_tap_for_add_amount", comment: "")
        memoHintLabel.text = NSLocalizedString("msg_tap_for_add_memo", comment: "")
        feeMsgLabel.text = NSLocalizedString("msg_about_fee_tip", comment: "")
        reStakeBtn.setTitle(NSLocalizedString("str_switch_validator", comment: ""), for: .normal)
    }
    
    @objc func onClickFromValidator() {
        let baseSheet = BaseSheet(nibName: "BaseSheet", bundle: nil)
        baseSheet.targetChain = selectedChain
        baseSheet.sheetDelegate = self
        if selectedChain is ChainInitia {
            baseSheet.sheetType = .SelectInitiaUnStakeValidator
        } else if selectedChain is ChainZenrock {
            baseSheet.sheetType = .SelectZenrockUnStakeValidator
        } else {
            baseSheet.sheetType = .SelectUnStakeValidator
        }
        onStartSheet(baseSheet, 680, 0.8)
    }
    
    func onUpdateFromValidatorView() {
        fromMonikerImg.image = UIImage(named: "iconValidatorDefault")
        if let initiaFetcher {
            fromMonikerImg.setMonikerImg(selectedChain, fromValidatorInitia!.operatorAddress)
            fromMonikerLabel.text = fromValidatorInitia!.description_p.moniker
            if (fromValidatorInitia!.jailed) {
                fromJailedTag.isHidden = false
            } else {
                fromInactiveTag.isHidden = initiaFetcher.isActiveValidator(fromValidatorInitia!)
            }
            
            let stakeDenom = selectedChain.stakeDenom!
            if let msAsset = BaseData.instance.getAsset(selectedChain.apiName, stakeDenom) {
                let staked = initiaFetcher.initiaDelegations.filter({ $0.delegation.validatorAddress == fromValidatorInitia?.operatorAddress }).first?.balance.filter({ $0.denom == stakeDenom }).first?.amount
                let stakingAmount = NSDecimalNumber(string: staked).multiplying(byPowerOf10: -msAsset.decimals!)
                fromStakedLabel?.attributedText = WDP.dpAmount(stakingAmount.stringValue, fromStakedLabel!.font, 6)
            }
            
        } else if let zenrockFetcher {
            fromMonikerImg.setMonikerImg(selectedChain, fromValidatorZenrock!.operatorAddress)
            fromMonikerLabel.text = fromValidatorZenrock!.description_p.moniker
            if (fromValidatorZenrock!.jailed) {
                fromJailedTag.isHidden = false
            } else {
                fromInactiveTag.isHidden = zenrockFetcher.isActiveValidator(fromValidatorZenrock!)
            }
            
            let stakeDenom = selectedChain.stakeDenom!
            if let msAsset = BaseData.instance.getAsset(selectedChain.apiName, stakeDenom) {
                let staked = zenrockFetcher.delegations.filter { $0.delegation.validatorAddress == fromValidatorZenrock?.operatorAddress }.first?.balance.amount
                let stakingAmount = NSDecimalNumber(string: staked).multiplying(byPowerOf10: -msAsset.decimals!)
                fromStakedLabel?.attributedText = WDP.dpAmount(stakingAmount.stringValue, fromStakedLabel!.font, 6)
            }

        } else {
            fromMonikerImg.setMonikerImg(selectedChain, fromValidator!.operatorAddress)
            fromMonikerLabel.text = fromValidator!.description_p.moniker
            if (fromValidator!.jailed) {
                fromJailedTag.isHidden = false
            } else {
                fromInactiveTag.isHidden = cosmosFetcher.isActiveValidator(fromValidator!)
            }
            
            let stakeDenom = selectedChain.stakeDenom!
            if let msAsset = BaseData.instance.getAsset(selectedChain.apiName, stakeDenom) {
                let staked = cosmosFetcher.cosmosDelegations.filter { $0.delegation.validatorAddress == fromValidator?.operatorAddress }.first?.balance.amount
                let stakingAmount = NSDecimalNumber(string: staked).multiplying(byPowerOf10: -msAsset.decimals!)
                fromStakedLabel?.attributedText = WDP.dpAmount(stakingAmount.stringValue, fromStakedLabel!.font, 6)
            }
        }
        
        onSimul()
    }
    
    @objc func onClickToValidator() {
        let baseSheet = BaseSheet(nibName: "BaseSheet", bundle: nil)
        if let initiaFetcher {
            baseSheet.initiaValidators = initiaFetcher.initiaValidators.filter { $0 != fromValidatorInitia }
            baseSheet.sheetType = .SelectInitiaValidator
            
        } else if let zenrockFetcher {
            baseSheet.zenrockValidators = zenrockFetcher.validators.filter { $0 != fromValidatorZenrock }
            baseSheet.sheetType = .SelectZenrockValidator
            
        } else {
            baseSheet.validators = cosmosFetcher.cosmosValidators.filter { $0 != fromValidator }
            baseSheet.sheetType = .SelectValidator
        }
        
        baseSheet.targetChain = selectedChain
        baseSheet.sheetDelegate = self
        onStartSheet(baseSheet, 680, 0.8)
    }
    
    func onUpdateToValidatorView() {
        toMonikerImg.image = UIImage(named: "iconValidatorDefault")
        
        if let initiaFetcher {
            toMonikerImg.setMonikerImg(selectedChain, toValidatorInitia!.operatorAddress)
            toMonikerLabel.text = toValidatorInitia!.description_p.moniker
            if (toValidatorInitia!.jailed) {
                toJailedTag.isHidden = false
            } else {
                toInactiveTag.isHidden = initiaFetcher.isActiveValidator(toValidatorInitia!)
            }
            
            let commission = NSDecimalNumber(string: toValidatorInitia!.commission.commissionRates.rate).multiplying(byPowerOf10: -16)
            toCommLabel?.attributedText = WDP.dpAmount(commission.stringValue, toCommLabel!.font, 2)
            
        } else if let zenrockFetcher {
            toMonikerImg.setMonikerImg(selectedChain, toValidatorZenrock!.operatorAddress)
            toMonikerLabel.text = toValidatorZenrock!.description_p.moniker
            if (toValidatorZenrock!.jailed) {
                toJailedTag.isHidden = false
            } else {
                toInactiveTag.isHidden = zenrockFetcher.isActiveValidator(toValidatorZenrock!)
            }
            
            let commission = NSDecimalNumber(string: toValidatorZenrock!.commission.commissionRates.rate).multiplying(byPowerOf10: -16)
            toCommLabel?.attributedText = WDP.dpAmount(commission.stringValue, toCommLabel!.font, 2)

        } else {
            toMonikerImg.setMonikerImg(selectedChain, toValidator!.operatorAddress)
            toMonikerLabel.text = toValidator!.description_p.moniker
            if (toValidator!.jailed) {
                toJailedTag.isHidden = false
            } else {
                toInactiveTag.isHidden = cosmosFetcher.isActiveValidator(toValidator!)
            }
            
            let commission = NSDecimalNumber(string: toValidator!.commission.commissionRates.rate).multiplying(byPowerOf10: -16)
            toCommLabel?.attributedText = WDP.dpAmount(commission.stringValue, toCommLabel!.font, 2)
        }
        
        onSimul()
    }
    
    @objc func onClickAmount() {
        let amountSheet = TxAmountSheet(nibName: "TxAmountSheet", bundle: nil)
        amountSheet.selectedChain = selectedChain
        amountSheet.msAsset = BaseData.instance.getAsset(selectedChain.apiName, selectedChain.stakeDenom!)
        amountSheet.availableAmount = availableAmount
        if let existedAmount = toCoin?.amount {
            amountSheet.existedAmount = NSDecimalNumber(string: existedAmount)
        }
        amountSheet.sheetDelegate = self
        amountSheet.sheetType = .TxRedelegate
        onStartSheet(amountSheet, 240, 0.6)
    }
    
    func onUpdateAmountView(_ amount: String) {
        let stakeDenom = selectedChain.stakeDenom!
        toCoin = Cosmos_Base_V1beta1_Coin.with {  $0.denom = stakeDenom; $0.amount = amount }
        
        if let msAsset = BaseData.instance.getAsset(selectedChain.apiName, stakeDenom) {
            WDP.dpCoin(msAsset, toCoin, nil, amountDenomLabel, amountLabel, msAsset.decimals)
            amountHintLabel.isHidden = true
            amountLabel.isHidden = false
            amountDenomLabel.isHidden = false
        }
        onSimul()
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
        if let initiaFetcher {
            if let delegated = initiaFetcher.initiaDelegations.filter({ $0.delegation.validatorAddress == fromValidatorInitia?.operatorAddress }).first {
                availableAmount = NSDecimalNumber(string: delegated.balance.filter({ $0.denom == selectedChain.stakeDenom }).first?.amount)
            }
            
        } else if let zenrockFetcher {
            if let delegated = zenrockFetcher.delegations.filter({ $0.delegation.validatorAddress == fromValidatorZenrock?.operatorAddress }).first {
                availableAmount = NSDecimalNumber(string: delegated.balance.amount)
            }

        } else {
            if let delegated = cosmosFetcher.cosmosDelegations.filter({ $0.delegation.validatorAddress == fromValidator?.operatorAddress }).first {
                availableAmount = NSDecimalNumber(string: delegated.balance.amount)
            }
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
        reStakeBtn.isEnabled = true
    }
    
    @IBAction func onClickRestake(_ sender: BaseButton) {
        let pinVC = UIStoryboard.PincodeVC(self, .ForDataCheck)
        self.present(pinVC, animated: true)
    }
    
    
    func onSimul() {
        if (toCoin == nil ) { return }
        view.isUserInteractionEnabled = false
        reStakeBtn.isEnabled = false
        loadingView.isHidden = false
        
        if (selectedChain.isSimulable() == false) {
            return onUpdateWithSimul(nil)
        }
        
        Task {
            do {
                if let simulReq = try await Signer.genSimul(selectedChain, onBindRedelegateMsg(), txMemo, txFee, nil),
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
    
    func onBindRedelegateMsg() -> [Google_Protobuf_Any] {
        if selectedChain is ChainInitia {
            let redelegate = Initia_Mstaking_V1_MsgBeginRedelegate.with {
                $0.delegatorAddress = selectedChain.bechAddress!
                $0.validatorSrcAddress = fromValidatorInitia!.operatorAddress
                $0.validatorDstAddress = toValidatorInitia!.operatorAddress
                $0.amount = [toCoin!]
            }
            return Signer.genRedelegateMsg(redelegate)
            
        } else if selectedChain is ChainZenrock {
            let redelegate = Zrchain_Validation_MsgBeginRedelegate.with {
                $0.delegatorAddress = selectedChain.bechAddress!
                $0.validatorSrcAddress = fromValidatorZenrock!.operatorAddress
                $0.validatorDstAddress = toValidatorZenrock!.operatorAddress
                $0.amount = toCoin!
            }
            return Signer.genRedelegateMsg(redelegate)
            
        } else if selectedChain is ChainBabylon {
            let redelegate = Babylon_Epoching_V1_MsgWrappedBeginRedelegate.with {
                $0.msg.delegatorAddress = selectedChain.bechAddress!
                $0.msg.validatorSrcAddress = fromValidator!.operatorAddress
                $0.msg.validatorDstAddress = toValidator!.operatorAddress
                $0.msg.amount = toCoin!
            }
            return Signer.genRedelegateMsg(redelegate)
            
        } else {
            let redelegate = Cosmos_Staking_V1beta1_MsgBeginRedelegate.with {
                $0.delegatorAddress = selectedChain.bechAddress!
                $0.validatorSrcAddress = fromValidator!.operatorAddress
                $0.validatorDstAddress = toValidator!.operatorAddress
                $0.amount = toCoin!
            }
            return Signer.genRedelegateMsg(redelegate)

        }
    }

}

extension CosmosRedelegate: BaseSheetDelegate, MemoDelegate, AmountSheetDelegate, PinDelegate {
    func onSelectedSheet(_ sheetType: SheetType?, _ result: Dictionary<String, Any>) {
        if (sheetType == .SelectUnStakeValidator) {
            if let validatorAddress = result["validatorAddress"] as? String {
                fromValidator = cosmosFetcher.cosmosValidators.filter({ $0.operatorAddress == validatorAddress }).first!
                if fromValidator == toValidator {
                    toValidator = cosmosFetcher.cosmosValidators.filter({ $0.operatorAddress != validatorAddress }).first
                    onUpdateToValidatorView()
                }
                onUpdateFromValidatorView()
                onUpdateFeeView()
            }
            
        } else if (sheetType == .SelectValidator) {
            if let validatorAddress = result["validatorAddress"] as? String {
                toValidator = cosmosFetcher.cosmosValidators.filter({ $0.operatorAddress == validatorAddress }).first!
                onUpdateToValidatorView()
                onUpdateFeeView()
            }
            
        } else if (sheetType == .SelectFeeDenom) {
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
        } else if (sheetType == .SelectInitiaUnStakeValidator) {
            if let validatorAddress = result["validatorAddress"] as? String, let initiaFetcher {
                fromValidatorInitia = initiaFetcher.initiaValidators.filter({ $0.operatorAddress == validatorAddress }).first!
                if fromValidatorInitia == toValidatorInitia {
                    toValidatorInitia = initiaFetcher.initiaValidators.filter({ $0.operatorAddress != validatorAddress }).first
                    onUpdateToValidatorView()
                }
                onUpdateFromValidatorView()
                onUpdateFeeView()
            }

        } else if (sheetType == .SelectInitiaValidator) {
            if let validatorAddress = result["validatorAddress"] as? String, let initiaFetcher {
                toValidatorInitia = initiaFetcher.initiaValidators.filter({ $0.operatorAddress == validatorAddress }).first!
                onUpdateToValidatorView()
                onUpdateFeeView()
            }
        } else if (sheetType == .SelectZenrockUnStakeValidator) {
            if let validatorAddress = result["validatorAddress"] as? String, let zenrockFetcher {
                fromValidatorZenrock = zenrockFetcher.validators.filter({ $0.operatorAddress == validatorAddress }).first!
                if fromValidatorZenrock == toValidatorZenrock {
                    toValidatorZenrock = zenrockFetcher.validators.filter({ $0.operatorAddress != validatorAddress }).first
                    onUpdateToValidatorView()
                }
                onUpdateFromValidatorView()
                onUpdateFeeView()
            }

        } else if (sheetType == .SelectZenrockValidator) {
            if let validatorAddress = result["validatorAddress"] as? String, let zenrockFetcher {
                toValidatorZenrock = zenrockFetcher.validators.filter({ $0.operatorAddress == validatorAddress }).first!
                onUpdateToValidatorView()
                onUpdateFeeView()
            }
        }
    }
    
    func onInputedMemo(_ memo: String) {
        onUpdateMemoView(memo)
    }
    
    func onInputedAmount(_ type: AmountSheetType?, _ amount: String) {
        onUpdateAmountView(amount)
    }
    
    func onPinResponse(_ request: LockType, _ result: UnLockResult) {
        if (result == .success) {
            view.isUserInteractionEnabled = false
            reStakeBtn.isEnabled = false
            loadingView.isHidden = false
            Task {
                do {
                    if let broadReq = try await Signer.genTx(selectedChain, onBindRedelegateMsg(), txMemo, txFee, nil),
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
