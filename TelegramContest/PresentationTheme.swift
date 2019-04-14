//
//  PresentationTheme.swift
//  TelegramContest
//
//  Created by Philip on 3/23/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

// presentationTheme
class PresentationTheme {
    let statusBarStyle: UIStatusBarStyle
    let isDark: Bool
    
    let headerTextColor: UIColor
    let navigationBarSeparatorColor: UIColor
    let tableViewBackgroundColor: UIColor
    let cellBackgroundColor: UIColor
    let switchThemeText: String
    let switchThemeTextColor: UIColor
    let selectionTitleTextColor: UIColor
    let selectionSeparatorColor: UIColor
    
    let selectedViewArrowColor: UIColor
    let selectedViewBackgroundColor: UIColor
    let nonSelectedViewBackgroudColor: UIColor
    
    let yAxisZeroLineColor: UIColor
    let yAxisOtherLineColor: UIColor
    let axisLabelTextColor: UIColor
    let axisDefaultGridColor: UIColor
    let axisAreaGridColor: UIColor
    
    let nonSelectedMaskColor: UIColor
    
    let tooltipBackground: UIColor
    let tooltipGridColor: UIColor
    let tooltipAreaGridColor: UIColor
    let tooltipArrowColor: UIColor
    let tooltipInfoTitleColor: UIColor

    static let dayTheme = PresentationTheme(
        statusBarStyle: .default,
        isDark: false,
        
        headerTextColor: UIColor(hex: "#6D6D72"),
        navigationBarSeparatorColor: UIColor(hex: "#B1B1B1"),
        tableViewBackgroundColor: UIColor(hex: "#EFEFF4"),
        cellBackgroundColor: .white,
        switchThemeText: "Night Mode",
        switchThemeTextColor: UIColor(hex: "#007AFF"),
        selectionTitleTextColor: .black,
        selectionSeparatorColor: UIColor(hex: "#C8C7CC"),
        
        selectedViewArrowColor: .white,
        selectedViewBackgroundColor: UIColor(hex: "#C0D1E1"),
        nonSelectedViewBackgroudColor: UIColor(hex: "#E2EEF9").withAlphaComponent(0.6),
        
        yAxisZeroLineColor: UIColor(hex: "#E1E2E3"),
        yAxisOtherLineColor: UIColor(hex: "#F3F3F3"),

        axisLabelTextColor: UIColor(hex: "#989EA3"),
        axisDefaultGridColor: UIColor(hex: "#182D3B").withAlphaComponent(0.1),
        axisAreaGridColor: UIColor(hex: "#182D3B").withAlphaComponent(0.1),
        
        nonSelectedMaskColor: UIColor(hex: "#FFFFFF").withAlphaComponent(0.5),
        
        tooltipBackground: UIColor(hex: "#F4F4F7"),
        tooltipGridColor: UIColor.black.withAlphaComponent(0.2),
        tooltipAreaGridColor: UIColor.black.withAlphaComponent(0.2),
        tooltipArrowColor: UIColor(hex: "#C4C7CD"),
        tooltipInfoTitleColor: UIColor(hex: "#6D6D72")
    )
    
    static let nightTheme = PresentationTheme(
        statusBarStyle: .lightContent,
        isDark: true,
        
        headerTextColor: UIColor(hex: "#5B6B7F"),
        navigationBarSeparatorColor: UIColor(hex: "#131A23"),
        tableViewBackgroundColor: UIColor(hex: "#18222D"),
        cellBackgroundColor: UIColor(hex: "#212F3F"),
        switchThemeText: "Day Mode",
        switchThemeTextColor: UIColor(hex: "#2EA6FE"),
        selectionTitleTextColor: UIColor(hex: "#FEFEFE"),
        selectionSeparatorColor: UIColor(hex: "#121A23"),
        
        selectedViewArrowColor: .white,
        selectedViewBackgroundColor: UIColor(hex: "#56626D"),
        nonSelectedViewBackgroudColor: UIColor(hex: "#18222D").withAlphaComponent(0.6),
        
        yAxisZeroLineColor: UIColor(hex: "#131B23"),
        yAxisOtherLineColor: UIColor(hex: "#1B2734"),

        axisLabelTextColor: UIColor(hex: "#5D6D7E"),
        axisDefaultGridColor: UIColor(hex: "#8596AB").withAlphaComponent(0.1),
        axisAreaGridColor: UIColor.white.withAlphaComponent(0.15),

        nonSelectedMaskColor: UIColor(hex: "#212F3F").withAlphaComponent(0.5),
        
        tooltipBackground: UIColor(hex: "#19232F"),
        tooltipGridColor: UIColor(hex: "#8596AB").withAlphaComponent(0.2),
        tooltipAreaGridColor: UIColor.white.withAlphaComponent(0.4),
        tooltipArrowColor: UIColor(hex: "#59606D"),
        tooltipInfoTitleColor: UIColor(hex: "#FFFFFF")
    )
    init(statusBarStyle: UIStatusBarStyle,
         isDark: Bool,
         
         headerTextColor: UIColor,
         navigationBarSeparatorColor: UIColor,
         tableViewBackgroundColor: UIColor,
         cellBackgroundColor: UIColor,
         switchThemeText: String,
         switchThemeTextColor: UIColor,
         selectionTitleTextColor: UIColor,
         selectionSeparatorColor: UIColor,
         
         selectedViewArrowColor: UIColor,
         selectedViewBackgroundColor: UIColor,
         nonSelectedViewBackgroudColor: UIColor,
         
         yAxisZeroLineColor: UIColor,
         yAxisOtherLineColor: UIColor,
         axisLabelTextColor: UIColor,
         axisDefaultGridColor: UIColor,
         axisAreaGridColor: UIColor,
         
         nonSelectedMaskColor: UIColor,
         
         tooltipBackground: UIColor,
         tooltipGridColor: UIColor,
         tooltipAreaGridColor: UIColor,
         tooltipArrowColor: UIColor,
         tooltipInfoTitleColor: UIColor)
    {
        self.statusBarStyle = statusBarStyle
        self.isDark = isDark
        
        self.headerTextColor = headerTextColor
        self.navigationBarSeparatorColor = navigationBarSeparatorColor
        self.tableViewBackgroundColor = tableViewBackgroundColor
        self.cellBackgroundColor = cellBackgroundColor
        self.switchThemeText = switchThemeText
        self.switchThemeTextColor = switchThemeTextColor
        self.selectionTitleTextColor = selectionTitleTextColor
        self.selectionSeparatorColor = selectionSeparatorColor
        
        self.selectedViewArrowColor = selectedViewArrowColor
        self.selectedViewBackgroundColor = selectedViewBackgroundColor
        self.nonSelectedViewBackgroudColor = nonSelectedViewBackgroudColor
        
        self.yAxisZeroLineColor = yAxisZeroLineColor
        self.yAxisOtherLineColor = yAxisOtherLineColor

        self.axisLabelTextColor = axisLabelTextColor
        self.axisDefaultGridColor = axisDefaultGridColor
        self.axisAreaGridColor = axisAreaGridColor
        
        self.nonSelectedMaskColor = nonSelectedMaskColor
        
        self.tooltipBackground = tooltipBackground
        self.tooltipGridColor = tooltipGridColor
        self.tooltipAreaGridColor = tooltipAreaGridColor
        self.tooltipArrowColor = tooltipArrowColor
        self.tooltipInfoTitleColor = tooltipInfoTitleColor
    }
    
    func axisGridColor(forChartType type: ChartDataSet.ChartType) -> UIColor {
        if type == .area {
            return axisAreaGridColor
        }
        return axisDefaultGridColor
    }
    
    private let arrowSize = CGSize(width: 13/3, height: 34/3)
    private var masksCache = [String:UIImage]()
    func selectedMaskImage(withHeight height: CGFloat, sliderWidth: CGFloat) -> UIImage? {
        let key = "\(height) \(sliderWidth) \(isDark)"
        if let mask = masksCache[key] {
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
        masksCache[key] = result
        return result
    }
}
