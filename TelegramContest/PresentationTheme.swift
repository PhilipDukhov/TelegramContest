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
    let selectedDatePointerLineColor: UIColor
    let gradientFirstPointColor: UIColor
    let gradientLastPointColor: UIColor
    let selectedDateTextColor: UIColor
    let axisLabelTextColor: UIColor
    
    static let dayTheme = PresentationTheme(
        statusBarStyle: .default,
        isDark: false,
        
        headerTextColor: UIColor(hex: "#6D6D72"),
        navigationBarSeparatorColor: UIColor(hex: "#B1B1B1"),
        tableViewBackgroundColor: UIColor(hex: "#EFEFF4"),
        cellBackgroundColor: .white,
        switchThemeText: "Switch to Night Mode",
        switchThemeTextColor: UIColor(hex: "#007EE5"),
        selectionTitleTextColor: .black,
        selectionSeparatorColor: UIColor(hex: "#C8C7CC"),
        
        selectedViewArrowColor: .white,
        selectedViewBackgroundColor: UIColor(red: 201/255,
                                             green: 209/255,
                                             blue: 219/255,
                                             alpha: 0.96),
        nonSelectedViewBackgroudColor: UIColor(hex: "#F5F5F5").withAlphaComponent(0.72),
        
        yAxisZeroLineColor: UIColor(hex: "#E1E2E3"),
        yAxisOtherLineColor: UIColor(hex: "#F3F3F3"),
        selectedDatePointerLineColor: UIColor(hex: "#CFD1D2"),
        gradientFirstPointColor: UIColor(hex: "#F0F0F5"),
        gradientLastPointColor: UIColor(hex: "#F7F7FD"),
        selectedDateTextColor: UIColor(hex: "#6D6D72"),
        axisLabelTextColor: UIColor(hex: "#989EA3")
    )
    
    static let nightTheme = PresentationTheme(
        statusBarStyle: .lightContent,
        isDark: true,
        
        headerTextColor: UIColor(hex: "#5B6B7F"),
        navigationBarSeparatorColor: UIColor(hex: "#131A23"),
        tableViewBackgroundColor: UIColor(hex: "#18222D"),
        cellBackgroundColor: UIColor(hex: "#212F3F"),
        switchThemeText: "Switch to Day Mode",
        switchThemeTextColor: UIColor(hex: "#1891FF"),
        selectionTitleTextColor: UIColor(hex: "#FEFEFE"),
        selectionSeparatorColor: UIColor(hex: "#121A23"),
        
        selectedViewArrowColor: .white,
        selectedViewBackgroundColor: UIColor(red: 56/255,
                                             green: 73/255,
                                             blue: 92/255,
                                             alpha: 0.89),
        nonSelectedViewBackgroudColor: UIColor(red: 27/255,
                                               green: 41/255,
                                               blue: 55/255,
                                               alpha: 0.67),
        
        yAxisZeroLineColor: UIColor(hex: "#131B23"),
        yAxisOtherLineColor: UIColor(hex: "#1B2734"),
        selectedDatePointerLineColor: UIColor(hex: "#131B23"),
        gradientFirstPointColor: UIColor(hex: "#1A2837"),
        gradientLastPointColor: UIColor(hex: "#1A2837"),
        selectedDateTextColor: UIColor(hex: "#FEFEFE"),
        axisLabelTextColor: UIColor(hex: "#5D6D7E")
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
         selectedDatePointerLineColor: UIColor,
         gradientFirstPointColor: UIColor,
         gradientLastPointColor: UIColor,
         selectedDateTextColor: UIColor,
         axisLabelTextColor: UIColor)
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
        self.selectedDatePointerLineColor = selectedDatePointerLineColor
        self.gradientFirstPointColor = gradientFirstPointColor
        self.gradientLastPointColor = gradientLastPointColor
        self.selectedDateTextColor = selectedDateTextColor
        self.axisLabelTextColor = axisLabelTextColor
    }
    
}
