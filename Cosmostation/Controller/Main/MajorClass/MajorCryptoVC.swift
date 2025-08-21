//
//  MajorCryptoVC.swift
//  Cosmostation
//
//  Created by yongjoo jung on 8/2/24.
//  Copyright © 2024 wannabit. All rights reserved.
//

import UIKit
import SwiftyJSON
import Lottie

class MajorCryptoVC: BaseVC {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingView: LottieAnimationView!
    @IBOutlet weak var floatingBtn: LottieAnimationView!
    
    var refresher: UIRefreshControl!
    
    var selectedChain: BaseChain!
    
    var suiBalances = Array<(String, NSDecimalNumber)>()
    
    var iotaBalances = Array<(String, NSDecimalNumber)>()

//    var btcBalances = NSDecimalNumber.zero
//    var btcPendingInput = NSDecimalNumber.zero
//    var btcPendingOutput = NSDecimalNumber.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        
        baseAccount = BaseData.instance.baseAccount
        
        loadingView.isHidden = false
        loadingView.animation = LottieAnimation.named("loading")
        loadingView.contentMode = .scaleAspectFit
        loadingView.loopMode = .loop
        loadingView.animationSpeed = 1.3
        loadingView.play()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "AssetSuiCell", bundle: nil), forCellReuseIdentifier: "AssetSuiCell")
        tableView.register(UINib(nibName: "AssetBtcCell", bundle: nil), forCellReuseIdentifier: "AssetBtcCell")
        tableView.register(UINib(nibName: "AssetCell", bundle: nil), forCellReuseIdentifier: "AssetCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.sectionHeaderTopPadding = 0.0
        
        refresher = UIRefreshControl()
        refresher.addTarget(self, action: #selector(onRequestFetch), for: .valueChanged)
        refresher.tintColor = .color01
        tableView.addSubview(refresher)
        
        if selectedChain.isSupportBTCStaking() {
            onSetFloatingBtn()
        }
        onUpdateView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onFetchDone(_:)), name: Notification.Name("FetchData"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onToggleValue(_:)), name: Notification.Name("ToggleHideValue"), object: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        refresher.endRefreshing()
        NotificationCenter.default.removeObserver(self, name: Notification.Name("FetchData"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("ToggleHideValue"), object: nil)
    }
    
    @objc func onFetchDone(_ notification: NSNotification) {
        let tag = notification.object as! String
        if (selectedChain != nil && selectedChain.tag == tag) {
            DispatchQueue.main.async {
                self.refresher.endRefreshing()
                self.suiBalances.removeAll()
                self.onUpdateView()
            }
        }
    }
    
    @objc func onToggleValue(_ notification: NSNotification) {
        tableView.reloadData()
    }

    @objc func onRequestFetch() {
        if (selectedChain.fetchState == FetchState.Busy) {
            refresher.endRefreshing()
        } else {
            DispatchQueue.global().async {
                self.selectedChain.fetchData(self.baseAccount.id)
            }
        }
    }
    
    func onUpdateView() {
        if let suiFetcher = (selectedChain as? ChainSui)?.getSuiFetcher() {
            suiBalances = suiFetcher.suiBalances
            //add zero sui for empty accoount
            if (suiBalances.filter { $0.0 == SUI_MAIN_DENOM }.count == 0) {
                suiBalances.append((SUI_MAIN_DENOM, NSDecimalNumber.zero))
            }
            suiBalances.sort {
                if ($0.0 == SUI_MAIN_DENOM) { return true }
                if ($1.0 == SUI_MAIN_DENOM) { return false }
                let value0 = suiFetcher.balanceValue($0.0)
                let value1 = suiFetcher.balanceValue($1.0)
                return value0.compare(value1).rawValue > 0 ? true : false
            }
            
        } else if let iotaFetcher = (selectedChain as? ChainIota)?.getIotaFetcher() {
            iotaBalances = iotaFetcher.iotaBalances
            if iotaBalances.filter({ $0.0 == IOTA_MAIN_DENOM }).count == 0 {
                iotaBalances.append((IOTA_MAIN_DENOM, NSDecimalNumber.zero))
            }
            iotaBalances.sort {
                if ($0.0 == IOTA_MAIN_DENOM) { return true }
                if ($1.0 == IOTA_MAIN_DENOM) { return false }
                let value0 = iotaFetcher.balanceValue($0.0)
                let value1 = iotaFetcher.balanceValue($1.0)
                return value0.compare(value1).rawValue > 0 ? true : false

            }
            
        } else if let btcFetcher = (selectedChain as? ChainBitCoin86)?.getBtcFetcher() {
//            btcBalances = btcFetcher.btcBalances
//            btcPendingInput = btcFetcher.btcPendingInput
//            btcPendingOutput = btcFetcher.btcPendingOutput
            
        }
        loadingView.isHidden = true
        tableView.reloadData()
    }
    
    func onSetFloatingBtn() {
        if (!BaseData.instance.showEvenReview()) { return }
        if (selectedChain is ChainBitCoin44 || selectedChain is ChainBitCoin49) { return }
        
        floatingBtn.animation = LottieAnimation.named("btcStaking")
        floatingBtn.contentMode = .scaleAspectFit
        floatingBtn.loopMode = .loop
        floatingBtn.animationSpeed = 1.3
        floatingBtn.play()
        floatingBtn.isHidden = false
        floatingBtn.tag = SheetType.MoveBabylonDappDetail.rawValue
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapFloatingBtn))
        tapGesture.cancelsTouchesInView = false
        floatingBtn.addGestureRecognizer(tapGesture)
    }
    
    @objc func tapFloatingBtn() {
        if BaseData.instance.getEcosystemPopUpActiveStatus(SheetType(rawValue: floatingBtn.tag)!) {
            let dappPopUpView = EcosystemPopUpSheet(nibName: "EcosystemPopUpSheet", bundle: nil)
            dappPopUpView.selectedChain = selectedChain
            dappPopUpView.tag = floatingBtn.tag
            dappPopUpView.sheetDelegate = self
            dappPopUpView.modalPresentationStyle = .overFullScreen
            self.present(dappPopUpView, animated: true)
            
        } else {
            onSelectedSheet(SheetType(rawValue: floatingBtn.tag)!, [:])
        }
    }

}

extension MajorCryptoVC: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if (selectedChain is ChainSui || selectedChain is ChainIota) {
            return 1
        } else if (selectedChain is ChainBitCoin86) {
            return 1
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = BaseHeader(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        if (selectedChain is ChainSui) {
            view.titleLabel.text = "Native Coins"
            view.cntLabel.text = String(suiBalances.count)
            
        } else if selectedChain is ChainIota {
            view.titleLabel.text = "Native Coins"
            view.cntLabel.text = String(iotaBalances.count)

        } else if (selectedChain is ChainBitCoin86) {
            view.titleLabel.text = "Native Coins"
            view.cntLabel.text = ""
            
        }
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if (selectedChain is ChainSui || selectedChain is ChainIota) {
            return 40
        } else if (selectedChain is ChainBitCoin86) {
            return 40
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (selectedChain is ChainSui) {
            return suiBalances.count
            
        } else if selectedChain is ChainIota {
            return iotaBalances.count
            
        } else if (selectedChain is ChainBitCoin86) {
            return 1
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (selectedChain is ChainSui) {
            if (indexPath.row == 0) {
                let cell = tableView.dequeueReusableCell(withIdentifier:"AssetSuiCell") as! AssetSuiCell
                cell.bindStakeAsset(selectedChain)
                return cell
                
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier:"AssetCell") as! AssetCell
                cell.bindSuiAsset(selectedChain, suiBalances[indexPath.row])
                return cell
            }
            
        } else if selectedChain is ChainIota {
            if (indexPath.row == 0) {
                let cell = tableView.dequeueReusableCell(withIdentifier:"AssetSuiCell") as! AssetSuiCell
                cell.bindIotaStakeAsset(selectedChain)
                return cell
                
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier:"AssetCell") as! AssetCell
                cell.bindIotaAsset(selectedChain, iotaBalances[indexPath.row])
                return cell
            }

            
        } else if (selectedChain is ChainBitCoin86) {
            let cell = tableView.dequeueReusableCell(withIdentifier:"AssetBtcCell") as! AssetBtcCell
            cell.bindBtcAsset(selectedChain)
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (selectedChain is ChainSui) {
            if (selectedChain.isTxFeePayable(.SUI_SEND_COIN) == false) {
                onShowToast(NSLocalizedString("error_not_enough_fee", comment: ""))
                return
            }
            
            let transfer = CommonTransfer(nibName: "CommonTransfer", bundle: nil)
            transfer.sendAssetType = .SUI_COIN
            transfer.fromChain = selectedChain
            transfer.toSendDenom = suiBalances[indexPath.row].0
            transfer.modalTransitionStyle = .coverVertical
            self.present(transfer, animated: true)
            
        } else if selectedChain is ChainIota {
            if (selectedChain.isTxFeePayable(.IOTA_SEND_COIN) == false) {
                onShowToast(NSLocalizedString("error_not_enough_fee", comment: ""))
                return
            }
            
            let transfer = CommonTransfer(nibName: "CommonTransfer", bundle: nil)
            transfer.sendAssetType = .IOTA_COIN
            transfer.fromChain = selectedChain
            transfer.toSendDenom = iotaBalances[indexPath.row].0
            transfer.modalTransitionStyle = .coverVertical
            self.present(transfer, animated: true)

            
        } else if (selectedChain is ChainBitCoin86) {
            Task {
                if let btcFetcher = (selectedChain as? ChainBitCoin86)?.getBtcFetcher() {
                    guard let fee = try await btcFetcher.initFee() else { return }
                    if Int(truncating: btcFetcher.btcBalances) > fee {
                        let transfer = CommonTransfer(nibName: "CommonTransfer", bundle: nil)
                        transfer.sendAssetType = .BTC_COIN
                        transfer.fromChain = selectedChain
                        transfer.toSendDenom = selectedChain.mainAssetSymbol().lowercased()
                        transfer.modalTransitionStyle = .coverVertical
                        self.present(transfer, animated: true)
                        
                    } else {
                        if btcFetcher.btcPendingInput != 0 {
                            onShowToast(NSLocalizedString("error_pending_balance", comment: ""))
                        } else {
                            onShowToast(NSLocalizedString("error_not_enough_balance_to_send", comment: ""))
                        }
                        return
                    }
                }
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        for cell in tableView.visibleCells {
            let hiddenFrameHeight = scrollView.contentOffset.y + (navigationController?.navigationBar.frame.size.height ?? 44) - cell.frame.origin.y
            if (hiddenFrameHeight >= 0 || hiddenFrameHeight <= cell.frame.size.height) {
                maskCell(cell: cell, margin: Float(hiddenFrameHeight))
            }
        }
        
        view.endEditing(true)
    }

    func maskCell(cell: UITableViewCell, margin: Float) {
        cell.layer.mask = visibilityMaskForCell(cell: cell, location: (margin / Float(cell.frame.size.height) ))
        cell.layer.masksToBounds = true
    }

    func visibilityMaskForCell(cell: UITableViewCell, location: Float) -> CAGradientLayer {
        let mask = CAGradientLayer()
        mask.frame = cell.bounds
        mask.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 1).cgColor]
        mask.locations = [NSNumber(value: location), NSNumber(value: location)]
        return mask;
    }
}

extension MajorCryptoVC: BaseSheetDelegate {
    func onSelectedSheet(_ sheetType: SheetType?, _ result: Dictionary<String, Any>) {
        if sheetType == .MoveBabylonDappDetail {
            let dappDetail = DappDetailVC(nibName: "DappDetailVC", bundle: nil)
            dappDetail.dappType = .INTERNAL_URL
            dappDetail.dappUrl = URL(string: selectedChain.btcStakingExplorerUrl())
            dappDetail.btcTargetChain = selectedChain
            dappDetail.modalPresentationStyle = .fullScreen
            self.present(dappDetail, animated: true)
        }
    }
}
