//
//  ChartTableViewCell.swift
//  TelegramContest
//
//  Created by Philip on 3/18/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class ChartTableViewCell: UITableViewCell {
    static let reuseIdentifier = "Chart"
    
    @IBOutlet weak var chartView: ChartView!
    @IBOutlet weak var separatorView: UIView!
    
    var presentationTheme: PresentationTheme! {
        didSet {
            chartView.presentationTheme = presentationTheme
            backgroundColor = presentationTheme.cellBackgroundColor
            separatorView.backgroundColor = presentationTheme.selectionSeparatorColor
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        separatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
    }
}
