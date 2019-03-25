//
//  SliderTableViewCell.swift
//  TelegramContest
//
//  Created by Philip on 3/17/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class SliderTableViewCell: ParentCell {
    override class var reuseIdentifier: String { return "Slider" }
    
    @IBOutlet weak var sliderView: SliderView!
    
    var valueChangedHandler: (() -> ())?
    
    override var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            sliderView.presentationTheme = presentationTheme
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        sliderView.addTarget(self, action: #selector(sliderViewValueChanged(_:)), for: .valueChanged)
    }
    
    @objc private func sliderViewValueChanged(_ sliderView: SliderView) {
        valueChangedHandler?()
    }
}
