//
//  CosmosReceiveVC.swift
//  Cosmostation
//
//  Created by yongjoo jung on 5/23/24.
//  Copyright © 2024 wannabit. All rights reserved.
//

import UIKit

class CosmosReceiveVC: BaseVC {
    
    @IBOutlet weak var tableView: UITableView!
    
    var selectedChain: BaseChain!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        baseAccount = BaseData.instance.baseAccount
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "ReceiveCell", bundle: nil), forCellReuseIdentifier: "ReceiveCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.sectionHeaderTopPadding = 0.0
        
        setFooterView()
    }
    
    func setFooterView() {
        let footerLabel = UILabel()
        footerLabel.text = "Powered by COSMOSTATION"
        footerLabel.textColor = .color04
        footerLabel.font = .fontSize11Medium
        footerLabel.textAlignment = .center
        footerLabel.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: 20)
        
        tableView.tableFooterView = footerLabel
    }

}

extension CosmosReceiveVC: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if (selectedChain.supportEvm) {
            return 2
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = BaseHeader(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        if (selectedChain.supportEvm) {
            if (section == 0) {
                view.titleLabel.text = "My Address (EVM Type)"
            } else {
                view.titleLabel.text = "My Address (COSMOS Type)"
            }
        } else {
            view.titleLabel.text = "My Address"
        }
        view.cntLabel.text = ""
        return view
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier:"ReceiveCell") as! ReceiveCell
        cell.bindReceive(baseAccount, selectedChain, indexPath.section)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var toCopyAddress = ""
        if selectedChain.supportEvm, indexPath.section == 0 {
            toCopyAddress = selectedChain.evmAddress!
        } else {
            toCopyAddress = selectedChain.bechAddress!
        }
        UIPasteboard.general.string = toCopyAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        self.onShowToast(NSLocalizedString("address_copied", comment: ""))
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        for cell in tableView.visibleCells {
            let hiddenFrameHeight = scrollView.contentOffset.y + (navigationController?.navigationBar.frame.size.height ?? 44) - cell.frame.origin.y
            if (hiddenFrameHeight >= 0 || hiddenFrameHeight <= cell.frame.size.height) {
                maskCell(cell: cell, margin: Float(hiddenFrameHeight))
            }
        }
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
