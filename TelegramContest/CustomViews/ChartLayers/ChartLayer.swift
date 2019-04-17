//
//  ChartLayer.swift
//  TelegramContest
//
//  Created by Philip on 4/10/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

private let lineWidth: CGFloat = 1.5

class ChartLayer: CALayer {
    
    let valuesLayer = ValuesLayer()
    let tooltipLayer = TooltipLayer()
    
    let startDateLayer = CATextLayer()
    private let separatorDateLayer = CATextLayer()
    let endDateLayer = CATextLayer()
    var titleDateLayers: [CATextLayer] { return [ startDateLayer, separatorDateLayer, endDateLayer ] }
    let zoomOutLayer = CATextLayer()
    
    let xAxisesLayer = AxisesTextsLayer()
    let yAxisesLayer = AxisesTextsLayer()
    let secondYAxisesLayer = AxisesTextsLayer()
    var axisesLayers: [AxisesTextsLayer] { return [ xAxisesLayer, yAxisesLayer, secondYAxisesLayer ] }
    
    private let titleDatesFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    var font: UIFont! {
        didSet {
            axisesLayers.forEach { $0.font = font }
        }
    }
    override init() {
        super.init()
        initialize()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    private func initialize() {
        contentsScale = UIScreen.main.scale
        [ valuesLayer,
          xAxisesLayer, yAxisesLayer, secondYAxisesLayer,
          tooltipLayer,
          startDateLayer, separatorDateLayer, endDateLayer
            ].forEach {
                addSublayer($0)
        }
        xAxisesLayer.masksToBounds = true
        valuesLayer.lineWidth = lineWidth
        tooltipLayer.lineWidth = lineWidth
        
        (titleDateLayers + [zoomOutLayer]).forEach {
            $0.setUIFont(titleDatesFont)
            $0.contentsScale = UIScreen.main.scale
        }
        separatorDateLayer.string = " - "
        separatorDateLayer.frame = CGRect(origin: CGPoint(x: 0, y: 12),
                                          size: separatorDateLayer.preferredFrameSize())
        
        zoomOutLayer.string = "< Zoom out"
        zoomOutLayer.frame = CGRect(origin: CGPoint(x: 0, y: 12),
                                    size: zoomOutLayer.preferredFrameSize())
    }
    
    func set(startDateString: String?, endDateString: String?) {
        var dateFrame = separatorDateLayer.frame
        startDateLayer.string = startDateString
        endDateLayer.string = endDateString
        if endDateString != nil {
            startDateLayer.alignmentMode = .right
            separatorDateLayer.isHidden = false
            dateFrame.origin.x = (bounds.width - dateFrame.width) / 2
            separatorDateLayer.frame = dateFrame
            startDateLayer.frame = CGRect(x: 0,
                                          y: dateFrame.minY,
                                          width: dateFrame.minX,
                                          height: dateFrame.height)
            endDateLayer.frame = CGRect(x: dateFrame.maxX,
                                        y: dateFrame.minY,
                                        width: bounds.width - dateFrame.maxX,
                                        height: dateFrame.height)
        }
        else {
            startDateLayer.alignmentMode = .center
            separatorDateLayer.isHidden = true
            startDateLayer.frame = CGRect(x: 0,
                                          y: dateFrame.minY,
                                          width: bounds.width,
                                          height: dateFrame.height)
            
        }
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        
        let chartFrame = bounds.inset(by: UIEdgeInsets(top: 39, left: 0, bottom: 20, right: 0))
        let axisFrame = bounds.inset(by: UIEdgeInsets(top: 20, left: 15, bottom: 0, right: 15))
        axisesLayers.forEach {
            $0.frame = axisFrame
        }
        valuesLayer.frame = chartFrame
        tooltipLayer.frame = chartFrame
    }
}
