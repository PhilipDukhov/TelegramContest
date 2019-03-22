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
}
