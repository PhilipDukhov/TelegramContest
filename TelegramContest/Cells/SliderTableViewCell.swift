//
//  SliderTableViewCell.swift
//  TelegramContest
//
//  Created by Philip on 3/17/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class SliderTableViewCell: ParentCell {
    let manager = ChartManager()
    private let valuesLayer = ValuesLayer()
    
    override class var reuseIdentifier: String { return "Slider" }
    
    @IBOutlet weak var sliderView: SliderView!
    
    var valueChangedHandler: (() -> ())?
    
    override var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            sliderView.presentationTheme = presentationTheme
            manager.presentationTheme = presentationTheme
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        sliderView.addTarget(self, action: #selector(sliderViewValueChanged(_:)), for: .valueChanged)
        sliderView.backgroundView.layer.addSublayer(valuesLayer)
        manager.delegate = self
    }
    
    @objc private func sliderViewValueChanged(_ sliderView: SliderView) {
        valueChangedHandler?()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        manager.update(chartFrame: sliderView.backgroundView.bounds,
                       axisFrame: sliderView.backgroundView.bounds)
        valuesLayer.frame = manager.chartFrame
    }
}

extension SliderTableViewCell: ChartManagerDelegate {
    func chartManagerUpdatedValues(_ chartManager: ChartManager) {
        valuesLayer.info = chartManager.valuesInfo
    }
}
