//
//  OkDeposit.swift
//  Cosmostation
//
//  Created by yongjoo jung on 2023/11/21.
//  Copyright © 2023 wannabit. All rights reserved.
//

import UIKit
import Lottie
import SwiftyJSON
import Alamofire
import SDWebImage

class OkDeposit: BaseVC {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var toDepositAssetCard: FixCardView!
    @IBOutlet weak var toDepositAssetTitle: UILabel!
    @IBOutlet weak var toDepositAssetImg: UIImageView!
    @IBOutlet weak var toDepositSymbolLabel: UILabel!
    @IBOutlet weak var toDepositAssetHint: UILabel!
    @IBOutlet weak var toDepositAmountLabel: UILabel!
    @IBOutlet weak var toDepositDenomLabel: UILabel!
    @IBOutlet weak var toDepositCurrencyLabel: UILabel!
    @IBOutlet weak var toDepositValueLabel: UILabel!
    
    @IBOutlet weak var memoCardView: FixCardView!
    @IBOutlet weak var memoTitle: UILabel!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var memoHintLabel: UILabel!
    
    @IBOutlet weak var feeSelectImg: UIImageView!
    @IBOutlet weak var feeSelectLabel: UILabel!
    @IBOutlet weak var feeAmountLabel: UILabel!
    @IBOutlet weak var feeDenomLabel: UILabel!
    @IBOutlet weak var feeCurrencyLabel: UILabel!
    @IBOutlet weak var feeValueLabel: UILabel!
    
    @IBOutlet weak var depositBtn: BaseButton!
    @IBOutlet weak var loadingView: LottieAnimationView!
    
    var selectedChain: ChainOktEVM!
    var oktFetcher: OktFetcher!
    var stakeDenom: String!
    var msAsset: MintscanAsset!
    var availableAmount = NSDecimalNumber.zero
    var toDepositAmount = NSDecimalNumber.zero
    var txMemo = ""
    
    var gasAmount = NSDecimalNumber(string: BASE_GAS_AMOUNT)
    var gasFee = NSDecimalNumber(string: OKT_BASE_FEE)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        baseAccount = BaseData.instance.baseAccount
        oktFetcher = selectedChain.getOktfetcher()
        stakeDenom = selectedChain.stakeDenom
        msAsset = BaseData.instance.getAsset(selectedChain.apiName, stakeDenom)
        
        onUpdateFeeView()
        
        toDepositAssetImg.sd_setImage(with: msAsset.assetImg(), placeholderImage: UIImage(named: "tokenDefault"))
        toDepositSymbolLabel.text = msAsset.symbol?.uppercased()
        
        let available = oktFetcher.oktBalanceAmount(stakeDenom)
        availableAmount = available.subtracting(gasFee)
        
        toDepositAssetCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickAmount)))
        memoCardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onClickMemo)))
    }
    
    override func setLocalizedString() {
        titleLabel.text = NSLocalizedString("str_deposit", comment: "")
        toDepositAssetHint.text = NSLocalizedString("msg_tap_for_add_amount", comment: "")
        memoHintLabel.text = NSLocalizedString("msg_tap_for_add_memo", comment: "")
        depositBtn.setTitle(NSLocalizedString("str_deposit", comment: ""), for: .normal)
    }

    @objc func onClickAmount() {
        let amountSheet = TxAmountLegacySheet(nibName: "TxAmountLegacySheet", bundle: nil)
        amountSheet.selectedChain = selectedChain
        amountSheet.tokenSymbol = msAsset.symbol?.uppercased()
        amountSheet.availableAmount = availableAmount
        if (toDepositAmount != NSDecimalNumber.zero) {
            amountSheet.existedAmount = toDepositAmount
        }
        amountSheet.sheetDelegate = self
        onStartSheet(amountSheet, 240, 0.6)
    }
    
    func onUpdateAmountView(_ amount: String?) {
        toDepositAssetHint.isHidden = false
        toDepositAmountLabel.isHidden = true
        toDepositDenomLabel.isHidden = true
        toDepositCurrencyLabel.isHidden = true
        toDepositValueLabel.isHidden = true
        
        if (amount?.isEmpty == true) {
            toDepositAmount = NSDecimalNumber.zero
            
        } else {
            toDepositAmount = NSDecimalNumber(string: amount)
            toDepositDenomLabel.text = msAsset.symbol?.uppercased()
            toDepositAmountLabel?.attributedText = WDP.dpAmount(toDepositAmount.stringValue, toDepositAmountLabel!.font, 18)
            toDepositAssetHint.isHidden = true
            toDepositAmountLabel.isHidden = false
            toDepositDenomLabel.isHidden = false
            
            guard let msAsset = BaseData.instance.getAsset(selectedChain.apiName, selectedChain.stakeDenom ?? selectedChain.mainAssetSymbol()) else { return }
            let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId)
            let toSendValue = msPrice.multiplying(by: toDepositAmount, withBehavior: handler6)
            WDP.dpValue(toSendValue, toDepositCurrencyLabel, toDepositValueLabel)
            toDepositCurrencyLabel.isHidden = false
            toDepositValueLabel.isHidden = false
            
        }
        onValidate()
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
    }
    
    func onUpdateFeeView() {
        feeSelectImg.sd_setImage(with: msAsset.assetImg(), placeholderImage: UIImage(named: "tokenDefault"))
        feeSelectLabel.text = stakeDenom.uppercased()
        
        let existCnt = oktFetcher.oktDeposits["validator_address"].arrayValue.count
        
        
        gasAmount = NSDecimalNumber(string: BASE_GAS_AMOUNT)
        gasFee = NSDecimalNumber(string: OKT_BASE_FEE)
        if (existCnt > 10) {
            gasFee = gasFee.multiplying(by: NSDecimalNumber(string: "3"))
            gasAmount = gasAmount.multiplying(by: NSDecimalNumber(string: "3"))
        } else if (existCnt > 20) {
            gasFee = gasFee.multiplying(by: NSDecimalNumber(string: "4"))
            gasAmount = gasAmount.multiplying(by: NSDecimalNumber(string: "4"))
        }
        
        guard let msAsset = BaseData.instance.getAsset(selectedChain.apiName, selectedChain.stakeDenom ?? selectedChain.mainAssetSymbol()) else { return }
        let msPrice = BaseData.instance.getPrice(msAsset.coinGeckoId)
        let feeValue = msPrice.multiplying(by: gasFee, withBehavior: handler6)
        feeAmountLabel?.attributedText = WDP.dpAmount(gasFee.stringValue, feeAmountLabel!.font, 18)
        feeDenomLabel.text = stakeDenom.uppercased()
        WDP.dpValue(feeValue, feeCurrencyLabel, feeValueLabel)
    }
    
    @IBAction func onClickDeposit(_ sender: UIButton) {
        let pinVC = UIStoryboard.PincodeVC(self, .ForDataCheck)
        self.present(pinVC, animated: true)
    }
    
    func onValidate() {
        depositBtn.isEnabled = false
        if (toDepositAmount == NSDecimalNumber.zero ) { return }
        if (txMemo.count > 300) { return }
        depositBtn.isEnabled = true
    }
    
}

extension OkDeposit: LegacyAmountSheetDelegate, MemoDelegate, PinDelegate {
    func onInputedAmount(_ amount: String) {
        onUpdateAmountView(amount)
    }
    
    func onInputedMemo(_ memo: String) {
        onUpdateMemoView(memo)
    }
    
    func onPinResponse(_ request: LockType, _ result: UnLockResult) {
        if (result == .success) {
            view.isUserInteractionEnabled = false
            depositBtn.isEnabled = false
            loadingView.isHidden = false
            
            Task {
                if let response = try? await broadcastOktDepositTx() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000), execute: {
                        print("response ", response)
                        self.loadingView.isHidden = true
                        
                        let txResult = CosmosTxResult(nibName: "CosmosTxResult", bundle: nil)
                        txResult.selectedChain = self.selectedChain
                        txResult.legacyResult = response
                        txResult.modalPresentationStyle = .fullScreen
                        self.present(txResult, animated: true)
                        
                    });
                }
            }
        }
    }
}

extension OkDeposit {
    
    func broadcastOktDepositTx() async throws -> JSON? {
        let depositCoin = L_Coin(stakeDenom, WUtils.getFormattedNumber(toDepositAmount, 18))
        let gasCoin = L_Coin(stakeDenom, WUtils.getFormattedNumber(gasFee, 18))
        let fee = L_Fee(gasAmount.stringValue, [gasCoin])
        
        let okMsg = L_Generator.oktDepositMsg(selectedChain.bechAddress!, depositCoin)
        let postData = L_Generator.postData([okMsg], fee, txMemo, selectedChain)
        let param = try! JSONSerialization.jsonObject(with: postData, options: .allowFragments) as? [String: Any]
        
        let url = oktFetcher.getLcd() + "txs"
        return try? await AF.request(url, method: .post, parameters: param, encoding: JSONEncoding.default, headers: [:]).serializingDecodable(JSON.self).value
    }
}
