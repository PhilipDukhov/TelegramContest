//
//  ChartView.swift
//  TelegramContest
//
//  Created by Philip on 3/19/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit


class ChartView: UIView {
    let manager = ChartManager()
//    let secondManager = ChartManager()
    
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
            chartLayer.tooltipLayer.presentationTheme = presentationTheme
            chartLayer.titleDateLayers.forEach { $0.foregroundColor = presentationTheme.chartDateTitleColor.cgColor }
            chartLayer.zoomOutLayer.foregroundColor = presentationTheme.zoomOutColor.cgColor
            
            
//            secondChartLayer.tooltipLayer.presentationTheme = presentationTheme
//            secondChartLayer.titleDateLayers.forEach { $0.foregroundColor = presentationTheme.chartDateTitleColor.cgColor }
//            secondChartLayer.zoomOutLayer.foregroundColor = presentationTheme.zoomOutColor.cgColor
        }
    }
    let chartLayer = ChartLayer()
//    let secondChartLayer = ChartLayer()

    override func awakeFromNib() {
        super.awakeFromNib()
        
        chartLayer.font = manager.font
        chartLayer.zoomOutLayer.isHidden = true
        layer.addSublayer(chartLayer)
        
//        secondChartLayer.font = manager.font
//        layer.addSublayer(secondChartLayer)
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:))))
        manager.delegate = self
//        secondManager.delegate = self
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        chartLayer.frame = bounds
        chartLayer.layoutIfNeeded()
//        secondChartLayer.frame = bounds
//        secondChartLayer.layoutIfNeeded()
        
        manager.update(chartFrame: chartLayer.valuesLayer.frame, axisFrame: chartLayer.xAxisesLayer.frame)
//        secondManager.update(chartFrame: chartLayer.valuesLayer.frame, axisFrame: chartLayer.xAxisesLayer.frame)
    }
    
    @objc private func tapHandler(_ gestureRecognizer: UITapGestureRecognizer) {
        let point = gestureRecognizer.location(in: self)
        defer {
            selectedDateChangedHandler?(selectedDate)
        }
        if let arrowFrame = chartLayer.tooltipLayer.arrowFrame,
            case let convertedFrame = layer.convert(arrowFrame, from: chartLayer.tooltipLayer.contentLayer),
            convertedFrame.controlOprimized.contains(point)
        {
            manager.selectedDate = nil
            return
        }
        manager.setSelectedDate(from: point)
    }
}

extension ChartView: ChartManagerDelegate {
    func chartManagerUpdatedValues(_ chartManager: ChartManager) {
        zip(chartLayer.axisesLayers, chartManager.axisesInfos).forEach { $0.info = $1 }
        chartLayer.valuesLayer.info = chartManager.valuesInfo
        chartLayer.tooltipLayer.info = chartManager.tooltipInfo
        chartLayer.set(startDateString: chartManager.selectedStartDateString,
                       endDateString: chartManager.selectedEndDateString)
        
        if chartManager.tooltipInfo != nil && chartLayer.tooltipLayer.onLayoutSubviews == nil {
            chartLayer.tooltipLayer.onLayoutSubviews = { [weak self] in
                if self?.chartLayer.tooltipLayer.isHidden == true {
                    chartManager.selectedDate = nil
                    self?.chartLayer.tooltipLayer.onLayoutSubviews = nil
                }
            }
        }
    }
}
