//
//  NightModeTableViewCell.swift
//  TelegramContest
//
//  Created by Philip on 3/23/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class NightModeTableViewCell: UITableViewCell {
    static let reuseIdentifier = "NightMode"

    @IBOutlet weak var label: UILabel!
    @IBOutlet var separatorViews: [UIView]!
    
    var presentationTheme: PresentationTheme! {
        didSet {
            backgroundColor = presentationTheme.cellBackgroundColor
            
            let attributedString = NSMutableAttributedString(string: presentationTheme.switchThemeText)
            attributedString.addAttribute(NSAttributedString.Key.kern, value: -0.5, range: NSMakeRange(0, attributedString.length))
            self.label.attributedText = attributedString
            
            label.textColor = presentationTheme.switchThemeTextColor
            separatorViews.forEach { $0.backgroundColor = presentationTheme.selectionSeparatorColor }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        separatorViews.forEach { $0.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true }
    }
}
