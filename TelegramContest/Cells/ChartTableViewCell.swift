//
//  ChartTableViewCell.swift
//  TelegramContest
//
//  Created by Philip on 3/18/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class ChartTableViewCell: ParentCell {
    override class var reuseIdentifier: String {return "Chart"}
    
    @IBOutlet weak var chartView: ChartView!
    @IBOutlet weak var separatorView: UIView!
    
    override var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            chartView.presentationTheme = presentationTheme
            separatorView.backgroundColor = presentationTheme.selectionSeparatorColor
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        separatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
    }
}
