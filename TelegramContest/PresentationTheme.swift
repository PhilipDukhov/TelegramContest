//
//  PresentationTheme.swift
//  TelegramContest
//
//  Created by Philip on 3/23/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

// presentationTheme
struct PresentationTheme {
    var statusBarStyle: UIStatusBarStyle
    var isDark: Bool
    
    var headerTextColor: UIColor
    var navigationBarSeparatorColor: UIColor
    var tableViewBackgroundColor: UIColor
    var cellBackgroundColor: UIColor
    var switchThemeText: String
    var switchThemeTextColor: UIColor
    var selectionTitleTextColor: UIColor
    var selectionSeparatorColor: UIColor
    var chartDateTitleColor: UIColor
    
    var selectedViewArrowColor: UIColor
    var selectedViewBackgroundColor: UIColor
    var nonSelectedViewBackgroudColor: UIColor
    
    var axisLabelDefaultTextColor: UIColor
    var axisLabelDefaultYTextColor: UIColor
    var axisLabelLineTextColor: UIColor
    
    var axisDefaultGridColor: UIColor
    var axisAreaGridColor: UIColor
    
    var nonSelectedMaskColor: UIColor
    
    var tooltipBackground: UIColor
    var tooltipGridColor: UIColor
    var tooltipAreaGridColor: UIColor
    var tooltipArrowColor: UIColor
    var tooltipInfoTitleColor: UIColor
    
    var zoomOutColor: UIColor
    
    static let dayTheme = PresentationTheme(isDark: false)
    static let nightTheme = PresentationTheme(isDark: true)

    init(isDark: Bool) {
        self.isDark = isDark
        if !isDark {
            if #available(iOS 13.0, *) {
                statusBarStyle = .darkContent
            } else {
                statusBarStyle = .default
            }
            
            headerTextColor = UIColor(hex: "#6D6D72")
            navigationBarSeparatorColor = UIColor(hex: "#B1B1B1")
            tableViewBackgroundColor = UIColor(hex: "#EFEFF4")
            cellBackgroundColor = .white
            switchThemeText = "Night Mode"
            switchThemeTextColor = UIColor(hex: "#007AFF")
            selectionTitleTextColor = .black
            selectionSeparatorColor = UIColor(hex: "#C8C7CC")
            chartDateTitleColor = .black
            
            selectedViewArrowColor = .white
            selectedViewBackgroundColor = UIColor(hex: "#C0D1E1")
            nonSelectedViewBackgroudColor = UIColor(hex: "#E2EEF9").withAlphaComponent(0.6)
            
            axisLabelDefaultTextColor = UIColor(hex: "#252529").withAlphaComponent(0.5)
            axisLabelDefaultYTextColor = UIColor(hex: "#252529").withAlphaComponent(0.5)
            axisLabelLineTextColor = UIColor(hex: "#8E8E93")
            
            axisDefaultGridColor = UIColor(hex: "#182D3B").withAlphaComponent(0.1)
            axisAreaGridColor = UIColor(hex: "#182D3B").withAlphaComponent(0.1)
            
            nonSelectedMaskColor = UIColor.white.withAlphaComponent(0.5)
            
            tooltipBackground = UIColor(hex: "#F4F4F7")
            tooltipGridColor = UIColor.black.withAlphaComponent(0.2)
            tooltipAreaGridColor = UIColor.black.withAlphaComponent(0.2)
            tooltipArrowColor = UIColor(hex: "#59606D").withAlphaComponent(0.3)
            tooltipInfoTitleColor = UIColor(hex: "#6D6D72")
            
            zoomOutColor = UIColor(hex: "#108BE3")
        }
        else {
            statusBarStyle = .lightContent
            
            headerTextColor = UIColor(hex: "#5B6B7F")
            navigationBarSeparatorColor = UIColor(hex: "#131A23")
            tableViewBackgroundColor = UIColor(hex: "#18222D")
            cellBackgroundColor = UIColor(hex: "#212F3F")
            switchThemeText = "Day Mode"
            switchThemeTextColor = UIColor(hex: "#2EA6FE")
            selectionTitleTextColor = UIColor(hex: "#FEFEFE")
            selectionSeparatorColor = UIColor(hex: "#121A23")
            chartDateTitleColor = .white
            
            selectedViewArrowColor = .white
            selectedViewBackgroundColor = UIColor(hex: "#56626D")
            nonSelectedViewBackgroudColor = UIColor(hex: "#18222D").withAlphaComponent(0.6)
            
            axisLabelDefaultTextColor = UIColor(hex: "#8596AB")
            axisLabelDefaultYTextColor = UIColor(hex: "#BACCE1").withAlphaComponent(0.6)
            axisLabelLineTextColor =  UIColor(hex: "#8596AB")
            
            axisDefaultGridColor =  UIColor(hex: "#8596AB").withAlphaComponent(0.1)
            axisAreaGridColor = UIColor.white.withAlphaComponent(0.15)
            
            nonSelectedMaskColor = UIColor(hex: "#212F3F").withAlphaComponent(0.5)
            
            tooltipBackground = UIColor(hex: "#19232F")
            tooltipGridColor =  UIColor(hex: "#8596AB").withAlphaComponent(0.2)
            tooltipAreaGridColor = UIColor.white.withAlphaComponent(0.4)
            tooltipArrowColor = UIColor(hex: "#D2D5D7")
            tooltipInfoTitleColor = UIColor(hex: "#FFFFFF")
            
            zoomOutColor = UIColor(hex: "#2EA6FE")
        }
    }
    
    func axisGridColor(forChartType type: ChartDataSet.ChartType) -> UIColor {
        if type == .area {
            return axisAreaGridColor
        }
        return axisDefaultGridColor
    }
    
    func xAxisLabelTextColor(forChartType type: ChartDataSet.ChartType) -> UIColor {
        if type == .line {
            return axisLabelLineTextColor
        }
        return axisLabelDefaultTextColor
    }
    
    func yAxisLabelTextColor(forChartType type: ChartDataSet.ChartType) -> UIColor {
        if type == .line {
            return axisLabelLineTextColor
        }
        return axisLabelDefaultYTextColor
    }
    
    private let arrowSize = CGSize(width: 13/3, height: 34/3)
    static private var masksCache = [String:UIImage]()
    func selectedMaskImage(withHeight height: CGFloat, sliderWidth: CGFloat) -> UIImage? {
        let key = "\(height) \(sliderWidth) \(isDark)"
        if let mask = PresentationTheme.masksCache[key] {
            return mask
        }
        let borderHeight: CGFloat = 1
        let whiteBorderWidth: CGFloat = isDark ? 0 : 1
        let contextSize = CGSize(width: sliderWidth * 2 + 1 + whiteBorderWidth * 4, height: height)
        UIGraphicsBeginImageContextWithOptions(contextSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setStrokeColor(selectedViewArrowColor.cgColor)
        
        if whiteBorderWidth != 0 {
            context.setFillColor(UIColor.white.cgColor)
            UIBezierPath(roundedRect: CGRect(origin: .zero,
                                             size: contextSize).insetBy(dx: 0, dy: -1),
                         cornerRadius: 6).fill()
            context.setFillColor(selectedViewBackgroundColor.cgColor)
            UIBezierPath(roundedRect: CGRect(origin: .zero,
                                             size: contextSize).insetBy(dx: 1, dy: 0),
                         cornerRadius: 6).fill()
            context.setFillColor(UIColor.white.cgColor)
            context.fill([
                CGRect(x: whiteBorderWidth + sliderWidth,
                       y: borderHeight,
                       width: whiteBorderWidth,
                       height: height - borderHeight * 2),
                CGRect(x: 2 * whiteBorderWidth + sliderWidth + 1,
                       y: borderHeight,
                       width: whiteBorderWidth,
                       height: height - borderHeight * 2)
                ])
        }
        else {
            context.setFillColor(selectedViewBackgroundColor.cgColor)
            UIBezierPath(roundedRect: CGRect(origin: .zero,
                                             size: contextSize),
                         cornerRadius: 6).fill()
        }
        
        context.clear(CGRect(x: sliderWidth + whiteBorderWidth * 2,
                             y: borderHeight,
                             width: 1,
                             height: height - borderHeight * 2))
        
        let arrowPath = UIBezierPath()
        arrowPath.lineCapStyle = .round
        arrowPath.lineWidth = 1.5
        arrowPath.flatness = 0.1
        arrowPath.lineJoinStyle = .round
        
        arrowPath.move(to: CGPoint(x: (sliderWidth + arrowSize.width) / 2 + whiteBorderWidth,
                                   y: (height - arrowSize.height) / 2))
        arrowPath.addLine(to: CGPoint(x: (sliderWidth - arrowSize.width) / 2 + whiteBorderWidth,
                                      y: height / 2))
        arrowPath.move(to: CGPoint(x: (sliderWidth - arrowSize.width) / 2 + whiteBorderWidth,
                                   y: height / 2))
        arrowPath.addLine(to: CGPoint(x: (sliderWidth + arrowSize.width) / 2 + whiteBorderWidth,
                                      y: (height + arrowSize.height) / 2))
        
        arrowPath.stroke()
        
        arrowPath.apply(CGAffineTransform(scaleX: -1, y: 1).concatenating(CGAffineTransform(translationX: 2 * (sliderWidth + whiteBorderWidth * 2) + 1, y: 0)))
        arrowPath.stroke()
        
        let result = UIGraphicsGetImageFromCurrentImageContext()?
            .resizableImage(withCapInsets: UIEdgeInsets(top: borderHeight, left: sliderWidth + whiteBorderWidth * 2,
                                                        bottom: borderHeight, right: sliderWidth + whiteBorderWidth * 2))
        UIGraphicsEndImageContext()
        PresentationTheme.masksCache[key] = result
        return result
    }
}
