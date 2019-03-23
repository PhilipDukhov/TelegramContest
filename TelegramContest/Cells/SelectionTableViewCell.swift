//
//  SelectionTableViewCell.swift
//  TelegramContest
//
//  Created by Philip on 3/18/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class SelectionTableViewCell: UITableViewCell {
    static let reuseIdentifier = "Selection"

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var colorMarkView: UIView!
    @IBOutlet weak var separatorView: UIView!
    @IBOutlet var separatorViewOffsetConstraint: NSLayoutConstraint!
    
    var presentationTheme: PresentationTheme! {
        didSet {
            backgroundColor = presentationTheme.cellBackgroundColor
            titleLabel.textColor = presentationTheme.selectedDateTextColor
            separatorView.backgroundColor = presentationTheme.selectionSeparatorColor
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        separatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
    }
}
