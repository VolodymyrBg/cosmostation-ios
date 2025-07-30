//
//  SelectOktValidatorCell.swift
//  Cosmostation
//
//  Created by yongjoo jung on 2023/11/23.
//  Copyright © 2023 wannabit. All rights reserved.
//

import UIKit
import SDWebImage
import SwiftyJSON

class SelectOktValidatorCell: UITableViewCell {
    
    @IBOutlet weak var rootView: UIView!
    @IBOutlet weak var logoImg: UIImageView!
    @IBOutlet weak var inactiveTag: UIImageView!
    @IBOutlet weak var jailedTag: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var checkedImg: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.selectionStyle = .none
    }
    
    override func prepareForReuse() {
        logoImg.sd_cancelCurrentImageLoad()
        logoImg.image = UIImage(named: "iconValidatorDefault")
        inactiveTag.isHidden = true
        jailedTag.isHidden = true
    }

    

    func onBindSelectValidator( _ chain: BaseChain, _ validatorInfo: JSON, _ selectedList: [JSON]) {
        logoImg.setMonikerImg(chain, validatorInfo["operator_address"].stringValue)
        nameLabel.text = validatorInfo["description"]["moniker"].stringValue
        
        if (validatorInfo["jailed"].boolValue) {
            jailedTag.isHidden = false
        } else {
            inactiveTag.isHidden = validatorInfo["status"].intValue == 2
        }
        
        
        if (selectedList.map { $0["operator_address"].stringValue }.contains(validatorInfo["operator_address"].stringValue)) {
            checkedImg.isHidden = false
        } else {
            checkedImg.isHidden = true
        }
    }
    
}
