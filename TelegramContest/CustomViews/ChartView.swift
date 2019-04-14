//
//  ChartView.swift
//  TelegramContest
//
//  Created by Philip on 3/19/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

fileprivate let datesSectionHeight: CGFloat = 18
fileprivate let axisOffset: CGFloat = 15

class ChartView: UIView {
    let manager = ChartManager()
    var chartData: ChartData! {
        set { manager.chartData = newValue! }
        get { return manager.chartData }
    }
    var selectedDate: TimeInterval? {
        set { manager.selectedDate = newValue }
        get { return manager.selectedDate }
    }
    
    var visibleSegment: Segment {
        set { manager.visibleSegment = newValue }
        get { return manager.visibleSegment }
    }
    var selectedDateChangedHandler: ((TimeInterval?)->())?
    var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            manager.presentationTheme = presentationTheme
            tooltipLayer.presentationTheme = presentationTheme
        }
    }
    
    private let valuesLayer = ValuesLayer()
    private let xAxisesLayer = AxisesTextsLayer()
    private let yAxisesLayer = AxisesTextsLayer()
    private let secondYAxisesLayer = AxisesTextsLayer()
    private var axisesLayers: [AxisesTextsLayer] { return [ xAxisesLayer, yAxisesLayer, secondYAxisesLayer ] }
    private let tooltipLayer = TooltipLayer()
    
    private let calcQueue = DispatchQueue(label: "calculations")
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        [ valuesLayer, xAxisesLayer, yAxisesLayer, secondYAxisesLayer, tooltipLayer].forEach {
            layer.addSublayer($0)
        }
        xAxisesLayer.masksToBounds = true
        axisesLayers.forEach { $0.font = manager.font }
        valuesLayer.lineWidth = lineWidth
        tooltipLayer.lineWidth = lineWidth
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:))))
        manager.delegate = self
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        manager.update(chartFrame: bounds.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: datesSectionHeight, right: 0)),
                       axisFrame: bounds.insetBy(dx: axisOffset, dy: 0))
        axisesLayers.forEach { $0.frame = manager.axisFrame }
        valuesLayer.frame = manager.chartFrame
        tooltipLayer.frame = manager.chartFrame
    }
    
    @objc private func tapHandler(_ gestureRecognizer: UITapGestureRecognizer) {
        let point = gestureRecognizer.location(in: self)
        defer {
            selectedDateChangedHandler?(selectedDate)
        }
        if tooltipLayer.tooltipInfoFrame?.contains(point) == true {
            manager.selectedDate = nil
            return
        }
        manager.setSelectedDate(from: point)
    }
}

extension ChartView: ChartManagerDelegate {
    func chartManagerUpdatedValues(_ chartManager: ChartManager) {
        zip(axisesLayers, chartManager.axisesInfos).forEach { $0.info = $1 }
        valuesLayer.info = chartManager.valuesInfo
        tooltipLayer.info = chartManager.tooltipInfo
    }
}
