//
//  ChartManager.swift
//  TelegramContest
//
//  Created by Philip on 4/14/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit


fileprivate let animationDuration: TimeInterval = 0.1

class CachedDateFormatter: DateFormatter {
    private var cachedStrings = [Date:String]()
    var dateDistance: TimeInterval?
    
    func clearCached() {
        cachedStrings.removeAll()
    }
    
    override func string(from date: Date) -> String {
        if let cachedString = cachedStrings[date] {
            return cachedString
        }
        let result = super.string(from: date)
        cachedStrings[date] = result
        return result
    }
}

struct Segment: Equatable {
    var start: TimeInterval
    var end: TimeInterval
    var lenth: TimeInterval {
        return end - start
    }
    static func == (lhs: Segment, rhs: Segment) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end
    }
}

protocol ChartManagerDelegate: NSObjectProtocol {
    func chartManagerUpdatedValues(_ chartManager: ChartManager)
}

class ChartManager {
    struct AnimatingRangeInfo {
        var current: ClosedRange<Int>?
        
        private var start: ClosedRange<Int>!
        private var animationStartDate: Date!
        private var end:ClosedRange<Int>!
        private(set) var animating = false
        
        mutating func calculateCurrentRange(withFinal range: ClosedRange<Int>) {
            animating = false
            guard current != nil && current != range else {
                current = range
                return
            }
            if end != range {
                animationStartDate = Date()
                start = current
                end = range
            }
            let part = (-animationStartDate.timeIntervalSinceNow + 0.01) / animationDuration
            guard part < 1 else {
                current = range
                return
            }
            animating = true
            current = start.lowerBound + Int(TimeInterval(range.lowerBound - start.lowerBound) * part)...start.upperBound + Int(TimeInterval(range.upperBound - start.upperBound) * part)
        }
    }
    private enum AxisesType {
        case x
        case firstY
        case secondY
        
        static var all: [AxisesType] { return [ .x, .firstY, .secondY ] }
    }
    struct PendingUpdate {
        var visibleSegment: Segment?
        var chartData: ChartData?
        var chartAndAxisFrames: (CGRect, CGRect)?
        var selectedDate: TimeInterval??
        
        var hasUpdates: Bool { return visibleSegment != nil || chartData != nil || chartAndAxisFrames != nil || selectedDate != nil}
    }
    
    let dateFormatter = CachedDateFormatter()
    let startTitleDateFormatter = CachedDateFormatter()
    let endTitleDateFormatter = CachedDateFormatter()
    let tooltipTitleDateFormatter = CachedDateFormatter()
    
    private var pendingUpdate = PendingUpdate()
    
    var xRange: ClosedRange<TimeInterval>!
    
    var selectedXRange: ClosedRange<TimeInterval>!
    var presentationTheme: PresentationTheme! {
        didSet {
            setNeedsUpdate()
        }
    }
    var allDates: [Date]!
    var dateStringSize = CGSize.zero
    
    var datePriorities: [Date: CGFloat]!
    var dateDistance: TimeInterval!
    
    let lineWidth: CGFloat = 1.5
    let font = UIFont.systemFont(ofSize: 11)
    var dataSets: [ChartDataSet]!
    var stackedDataSets: [(TimeInterval, [Int])]?
    var stackedPercentedDataSets: [(TimeInterval, [CGFloat])]?
    var selectedYRange = AnimatingRangeInfo()
    var secondSelectedYRange = AnimatingRangeInfo()
    var borderedXRange: ClosedRange<TimeInterval>!
    var barStep: CGFloat = 0
    
    var needsRedrawToAnimate = false
    
    var axisesInfos: [AxisesTextsLayer.Info?]!
    var valuesInfo: ValuesLayer.Info!
    var tooltipInfo: TooltipLayer.Info?
    var selectedStartDateString: String?
    var selectedEndDateString: String?
    
    var queue = DispatchQueue(label: "calculations")
    
    weak var delegate: ChartManagerDelegate?
    
    init() {
        startTitleDateFormatter.dateFormat = "d MMMM YYYY"
        endTitleDateFormatter.dateFormat = "YYYY MMMM d"
    }
    
    private(set) var chartFrame: CGRect!
    private(set) var axisFrame: CGRect!
    func update(chartFrame: CGRect, axisFrame: CGRect) {
        pendingUpdate.chartAndAxisFrames = (chartFrame, axisFrame)
        setNeedsUpdate()
    }
    
    // MARK: - ChartData
    private var _chartData: ChartData!
    var chartData: ChartData {
        set {
            pendingUpdate.chartData = newValue
            setNeedsUpdate()
        }
        get { return _chartData }
    }
    private func setChartData(_ newValue: ChartData) {
        if Thread.isMainThread {
            queue.async {
                self.setChartData(newValue)
            }
            return
        }
        defer {
            setNeedsUpdate()
        }
        let newData = _chartData != newValue
        _chartData = newValue
        generateDataSets()
        guard dataSets.count > 0 else { return }
        
        var minX: TimeInterval = .greatestFiniteMagnitude
        var maxX: TimeInterval = 0
        var datesSet = Set<Date>()
        for dataEntry in chartData.dataSets[0].values {
            minX = min(minX, dataEntry.x)
            maxX = max(maxX, dataEntry.x)
            datesSet.insert(Date(timeIntervalSince1970: dataEntry.x))
        }
        dateDistance = chartData.dataSets[0].values[1].x - chartData.dataSets[0].values[0].x
        switch dateDistance {
        case 60 * 60 * 24:
            dateFormatter.dateFormat = "MMM dd"
            tooltipTitleDateFormatter.dateFormat = "EEE, dd MMM YYYY"
            
        default:
            dateFormatter.dateFormat = "HH:mm"
            tooltipTitleDateFormatter.dateFormat = "HH:mm"
        }
        [dateFormatter, startTitleDateFormatter, endTitleDateFormatter, tooltipTitleDateFormatter].forEach {
            $0.clearCached()
            $0.dateDistance = dateDistance
        }
        allDates = Array(datesSet)
        calcDateStringSize()
        
        xRange = minX...maxX
        if newData {
            selectedYRange.current = nil
            secondSelectedYRange.current = nil
        }
        if axisFrame != nil {
            reorderDatesByPriority()
        }
    }
    
    // MARK: - SelectedDate
    var zoomed = false {
        didSet {
            setNeedsUpdate()
        }
    }
    private var _selectedDate: TimeInterval?
    var selectedDate: TimeInterval? {
        set {
            guard newValue != _selectedDate else {
                pendingUpdate.selectedDate = nil
                return
            }
            guard newValue != pendingUpdate.selectedDate else {
                return
            }
            pendingUpdate.selectedDate = newValue
            setNeedsUpdate()
        }
        get { return _selectedDate }
    }
    
    func setSelectedDate(from point: CGPoint) {
        let timestamp = TimeInterval((point.x - axisFrame.minX) / axisFrame.width * CGFloat(selectedXRange.length)) + selectedXRange.lowerBound
        selectedDate = allDates.map({($0, ($0.timeIntervalSince1970 - timestamp).magnitude)}).sorted(by: {$0.1 < $1.1}).first!.0.timeIntervalSince1970
        tooltipInfo = generateTooltipInfo()
        if chartData.type == .bar {
            valuesInfo = generateValuesInfo()
        }
    }
    
    // MARK: - VisibleSegment
    private var _visibleSegment: Segment!
    var visibleSegment: Segment {
        set {
            if newValue == _visibleSegment {
                pendingUpdate.visibleSegment = nil
                return
            }
            if newValue == pendingUpdate.visibleSegment {
                return
            }
            pendingUpdate.visibleSegment = newValue
            setNeedsUpdate()
        }
        get { return _visibleSegment }
    }
    private func setVisibleSegment(_ newValue: Segment) {
        if Thread.isMainThread {
            queue.async {
                self.setVisibleSegment(newValue)
            }
            return
        }
        _visibleSegment = newValue
        let dayTimestampForRangePart = { (range: ClosedRange<TimeInterval>, part: TimeInterval) in
            return range.lowerBound + range.length * part
        }
        selectedXRange = max(newValue.start, dayTimestampForRangePart(xRange, visibleSegment.start))...dayTimestampForRangePart(xRange, newValue.end)
    }
    
    private var needsUpdate = false
    private var updating = false
    func setNeedsUpdate() {
        guard !needsUpdate,
            axisFrame != nil || pendingUpdate.chartAndAxisFrames != nil,
            _chartData != nil || pendingUpdate.chartData != nil
            else { return }
        needsUpdate = true
        queue.async {
            self.updateValuesIfNeeded()
        }
    }
    
    private func updateValuesIfNeeded() {
        guard !updating, needsUpdate || pendingUpdate.hasUpdates || selectedYRange.animating || secondSelectedYRange.animating else { return }
        if let newValue = pendingUpdate.chartData {
            pendingUpdate.chartData = nil
            setChartData(newValue)
        }
        if let newValue = pendingUpdate.visibleSegment {
            pendingUpdate.visibleSegment = nil
            setVisibleSegment(newValue)
        }
        if let newValue = pendingUpdate.selectedDate {
            pendingUpdate.selectedDate = nil
            _selectedDate = newValue
        }
        if let (chartFrame, axisFrame) = pendingUpdate.chartAndAxisFrames {
            pendingUpdate.chartAndAxisFrames = nil
            self.chartFrame = chartFrame
            self.axisFrame = axisFrame
            reorderDatesByPriority()
        }
        let zoomed = self.zoomed
        needsUpdate = false
        updating = true
        var axisesInfos = Array<AxisesTextsLayer.Info?>(repeating: nil, count: AxisesType.all.count)
        var valuesInfo: ValuesLayer.Info?
        var tooltipInfo: TooltipLayer.Info?
        var selectedStartDateString: String?
        var selectedEndDateString: String?
        defer {
            updating = false
            DispatchQueue.main.async {
                self.axisesInfos = axisesInfos
                self.valuesInfo = valuesInfo
                self.tooltipInfo = tooltipInfo
                self.selectedStartDateString = selectedStartDateString
                self.selectedEndDateString = selectedEndDateString
                self.delegate?.chartManagerUpdatedValues(self)
            }
            queue.async {
                self.updateValuesIfNeeded()
            }
        }
        if chartData.type == .area, let selectedDate = selectedDate, zoomed {
            selectedStartDateString = startTitleDateFormatter.string(from: Date(timeIntervalSince1970: selectedDate))
            let index = dataSets[0].values.firstIndex(where: { $0.x == selectedDate })!
            let percentValues = self.percentValues(at: index)!
            var startAngle: CGFloat = 0
            let selectedOffset: CGFloat = 6
            let radius = min(chartFrame.width, chartFrame.height) / 2 - selectedOffset
            var pathInfos = [ValuesLayer.Info.PathInfo]()
            var textInfos = [ValuesLayer.Info.TextInfo]()
            for (i, percent) in percentValues.enumerated() {
                let endAngle = startAngle + CGFloat(percent) / 100 * CGFloat.pi * 2
                let text = "\(percent)%"
                var fontSize: CGFloat = 30
                let center = CGPoint(x: chartFrame.width / 2, y: chartFrame.height / 2)
                let midAngle = (endAngle + startAngle) / 2
                
                pathInfos.append(ValuesLayer.Info.PathInfo(path: {
                    let path = CGMutablePath()
                    path.move(to: center)
                    path.addArc(center: center,
                                radius: radius,
                                startAngle: startAngle,
                                endAngle: endAngle,
                                clockwise: false)
                    return path
                }(),
                                                           color: dataSets[i].color.cgColor))
                
                var innerRadius = radius * (1 - 1 / (1 + sin((endAngle - startAngle) / 2)))
                let innerCenter = CGPoint(x: center.x + cos(midAngle) * (radius - innerRadius),
                                          y: center.y + sin(midAngle) * (radius - innerRadius))
                innerRadius *= 0.75
                
                var textSize = CGSize.zero
                var step:CGFloat = -1
                while true {
                    textSize = NSString(string: text).size(withAttributes: [.font: UIFont.systemFont(ofSize: fontSize, weight: .semibold)])
                    if pow(textSize.width / 2, 2) + pow(textSize.height / 2, 2) <= pow(innerRadius, 2) {
                        if step == -1 {
                            step = 0.1
                        }
                    }
                    else {
                        if step == 0.1 {
                            break
                        }
                    }
                    fontSize += step
                    if fontSize == 0 {
                        break
                    }
                }
                textInfos.append(ValuesLayer.Info.TextInfo(string: text,
                                                           frame: CGRect(center: innerCenter, size: textSize),
                                                           font: UIFont.systemFont(ofSize: fontSize, weight: .semibold)))
                startAngle = endAngle
            }
            valuesInfo = ValuesLayer.Info(drawingMode: .fill,
                                          lineWidth: nil,
                                          pathInfos: pathInfos,
                                          textInfos: textInfos)
            return
        }
        if chartData.type == .bar {
            var newValue: CGFloat
            let firstValue = dataSets[0].values[1].x
            let secondValue = dataSets[0].values[0].x
            var aproxSteps = [CGFloat]()
            while true {
                newValue = (xPosition(for: firstValue) - xPosition(for: secondValue)).roundedScreenScaled(.up)
                if newValue == barStep || aproxSteps.contains(newValue) {
                    break
                }
                barStep = newValue
                aproxSteps.append(newValue)
            }
        }
        else {
            barStep = 0
        }
        var borderDates = (xRange.lowerBound, xRange.upperBound)
        for dataSet in dataSets {
            for dataEntry in dataSet.values where !selectedXRange.contains(dataEntry.x) {
                let position = xPosition(for: dataEntry.x)
                if dataEntry.x < selectedXRange.lowerBound && position < chartFrame.minX {
                    borderDates.0 = max(borderDates.0, dataEntry.x)
                }
                else if dataEntry.x > selectedXRange.upperBound && position > chartFrame.maxX {
                    borderDates.1 = min(borderDates.1, dataEntry.x)
                }
            }
        }
        borderedXRange = borderDates.0...borderDates.1
        
        func range(from values: [ChartDataEntry], minZero: Bool) -> ClosedRange<Int> {
            var minValue = minZero ? 0 : Int.max
            var maxValue = Int.min
            for dataEntry in values where borderedXRange.contains(dataEntry.x) {
                minValue = min(minValue, dataEntry.y)
                maxValue = max(maxValue, dataEntry.y)
            }
            minValue = max(minValue - (maxValue - minValue) / 20, 0)
            maxValue += (maxValue - minValue) / 20
            return minValue...maxValue
        }
        func animatedRange(from range: ClosedRange<Int>, oldValue: ClosedRange<Int>?, needsRedrawToAnimate: inout Bool) -> ClosedRange<Int> {
            if let oldValue = oldValue {
                let koeff = max(oldValue.length, range.length) / 20
                let diff = abs(oldValue.length - range.length)
                if koeff < diff {
                    needsRedrawToAnimate = true
                    return oldValue.lowerBound + (range.lowerBound - oldValue.lowerBound) * koeff / diff...oldValue.upperBound + (range.upperBound - oldValue.upperBound) * koeff / diff
                }
            }
            return range
        }
        if chartData.y_scaled {
            if let dataSet = chartData.dataSets.first, dataSets.contains(dataSet) {
                selectedYRange.calculateCurrentRange(withFinal: range(from: dataSet.values, minZero: false))
            }
            else {
                selectedYRange.current = nil
            }
            if let dataSet = chartData.dataSets.last, dataSets.contains(dataSet) {
                secondSelectedYRange.calculateCurrentRange(withFinal: range(from: dataSet.values, minZero: false))
            }
            else {
                secondSelectedYRange.current = nil
            }
        }
        else {
            secondSelectedYRange.current = nil
            if chartData.stacked && chartData.percentage {
                selectedYRange.current = 0...100
            }
            else if let stackedDataSets = stackedDataSets {
                var maxValue = stackedDataSets[0].1.reduce(0, +)
                for stackedDataSet in stackedDataSets where borderedXRange.contains(stackedDataSet.0) {
                    maxValue = max(maxValue, stackedDataSet.1.reduce(0, +))
                }
                maxValue += maxValue / 20
                selectedYRange.calculateCurrentRange(withFinal: 0...maxValue)
            }
            else {
                let values = dataSets.reduce(into: [ChartDataEntry]()) { $0 += $1.values }
                selectedYRange.calculateCurrentRange(withFinal: range(from: values,
                                                                      minZero: chartData.type == .bar))
            }
        }
        
        axisesInfos = AxisesType.all.map { generateAxisesInfo(for: $0) }
        valuesInfo = generateValuesInfo()
        tooltipInfo = generateTooltipInfo()
        let selectedStartDate = Date(timeIntervalSince1970: selectedXRange.lowerBound)
        let selectedEndDate = Date(timeIntervalSince1970: selectedXRange.upperBound)
        selectedStartDateString = startTitleDateFormatter.string(from: selectedStartDate)
        selectedEndDateString = Calendar.current.isDate(selectedStartDate, inSameDayAs:selectedEndDate) ? nil :  endTitleDateFormatter.string(from: selectedEndDate)
    }
    
    private func generateValuesInfo() -> ValuesLayer.Info? {
        switch chartData.type {
        case .area:
            if let stackedPercentedDataSets = stackedPercentedDataSets {
                var points = Array<[CGPoint]>(repeating: [CGPoint](), count: dataSets.count - 1)
                
                var point = CGPoint.zero
                for (x, values) in stackedPercentedDataSets where borderedXRange.contains(x) {
                    point.x = xPosition(for: x).rounded()
                    var sum: CGFloat = 0
                    for (j, value) in values.enumerated() where j != values.count - 1 {
                        sum += value
                        point.y = ((1 - sum / 100) * chartFrame.height).rounded()
                        points[j].append(point)
                    }
                }
                points.insert([
                    CGPoint(x: points[0].first!.x,
                            y: chartFrame.height),
                    CGPoint(x: points[0].last!.x,
                            y: chartFrame.height)
                    ], at: 0)
                points.append([
                    CGPoint(x: points[0].first!.x,
                            y: 0),
                    CGPoint(x: points[0].last!.x,
                            y: 0)
                    ])
                var pathInfos = [ValuesLayer.Info.PathInfo]()
                for i in 1..<points.count {
                    let path = CGMutablePath()
                    path.addLines(between: points[i] + points[i - 1].reversed())
                    pathInfos.append(ValuesLayer.Info.PathInfo(path: path,
                                                               color: dataSets[i - 1].color.cgColor))
                }
                return ValuesLayer.Info(drawingMode: .fillStroke,
                                        lineWidth: 1 / UIScreen.main.scale,
                                        pathInfos: pathInfos,
                                        textInfos: nil)
            }
            
        case .line:
            return ValuesLayer.Info(drawingMode: .stroke,
                                    lineWidth: lineWidth,
                                    pathInfos: dataSets.map({ dataSet -> ValuesLayer.Info.PathInfo in
                                        let range = (chartData.y_scaled && dataSet != chartData.dataSets[0] ? secondSelectedYRange : selectedYRange).current!
                                        let path = CGMutablePath()
                                        path.addLines(between: dataSet.values.filter({
                                            borderedXRange.contains($0.x)
                                        }).map({
                                            CGPoint(x: xPosition(for: $0.x),
                                                    y: yPosition(for: $0.y, range: range) - chartFrame.minY)
                                        }))
                                        return ValuesLayer.Info.PathInfo(path: path,
                                                                         color: dataSet.color.cgColor)
                                        
                                    }),
                                    textInfos: nil)
            
        case .bar:
            var rects = Array<[CGRect]>(repeating: [CGRect](), count: dataSets.count)
            var selectedRects = [[CGRect]]()
            
            var frame = CGRect.zero
            frame.size.width = barStep
            if let stackedDataSets = stackedDataSets {
                for (x, values) in stackedDataSets where borderedXRange.contains(x) {
                    frame.origin.x = (xPosition(for: x) - barStep / 2).roundedScreenScaled(.down)
                    frame.origin.y = chartFrame.height
                    var sum = 0
                    for (j, value) in values.enumerated() {
                        sum += value
                        frame.size.height = frame.origin.y
                        frame.origin.y = yPosition(for: sum).roundedScreenScaled - chartFrame.minY
                        frame.size.height -= frame.origin.y
                        if selectedDate == x {
                            selectedRects.append([frame])
                        }
                        else {
                            rects[j].append(frame)
                        }
                    }
                }
            }
            else {
                for (i, dataSet) in dataSets.enumerated() {
                    for value in dataSet.values where borderedXRange.contains(value.x) {
                        frame.origin.x = (xPosition(for: value.x) - barStep / 2).roundedScreenScaled(.down)
                        frame.origin.y = yPosition(for: value.y) - chartFrame.minY
                        frame.size.height = chartFrame.height - frame.origin.y
                        if selectedDate == value.x {
                            selectedRects.append([frame])
                        }
                        else {
                            rects[i].append(frame)
                        }
                    }
                }
            }
            var colors = dataSets.map({ $0.color.cgColor })
            if selectedDate != nil {
                let blendedColors = colors.map { $0 + presentationTheme.nonSelectedMaskColor.cgColor }
                if selectedRects.count > 0 {
                    colors = blendedColors + colors
                    rects += selectedRects
                }
                else {
                    colors = blendedColors
                }
            }
            
            return ValuesLayer.Info(drawingMode: .fill,
                                    lineWidth: nil,
                                    pathInfos: zip(rects, colors).map{ (rects, color) -> ValuesLayer.Info.PathInfo in
                                        let path = CGMutablePath()
                                        path.addRects(rects)
                                        return ValuesLayer.Info.PathInfo(path: path, color: color)
                },
                                    textInfos: nil)
        }
        return nil
    }
    
    private func xPosition(for value: TimeInterval, range: ClosedRange<TimeInterval>? = nil) -> CGFloat {
        let range = range ?? selectedXRange!
        return barStep / 2 + axisFrame.minX + CGFloat(value - range.lowerBound) / CGFloat(range.length) * (axisFrame.width - barStep)
    }
    
    private func yPosition(for value: Int, range: ClosedRange<Int>? = nil) -> CGFloat {
        let range = range ?? selectedYRange.current!
        return chartFrame.minY + (1 - CGFloat(value - range.lowerBound) / CGFloat(range.length)) * chartFrame.height
    }
    
    private func dateFrame(for date: Date, range: ClosedRange<TimeInterval>? = nil) -> CGRect {
        return CGRect(origin: CGPoint(x: xPosition(for: date.timeIntervalSince1970, range: range) - dateStringSize.width / 2,
                                      y: axisFrame.maxY - dateStringSize.height),
                      size: dateStringSize)
    }
    
    private func generateTooltipInfo() -> TooltipLayer.Info? {
        guard let selectedDate = selectedDate else { return nil }
        
        let index = dataSets[0].values.firstIndex(where: { $0.x == selectedDate })!
        var sum: Int? = chartData.stacked ? 0 : nil
        let percentValues = self.percentValues(at: index)
        
        var pointInfos = dataSets.enumerated().map { arg -> TooltipLayer.Info.PointInfo in
            let (i, dataSet) = arg
            let point = dataSet.values[index]
            let position: CGFloat
            if sum != nil {
                sum! += point.y
                position = yPosition(for: sum!) - chartFrame.minY
            }
            else {
                let range = (chartData.y_scaled && dataSet != chartData.dataSets[0] ? secondSelectedYRange : selectedYRange).current!
                position = yPosition(for: point.y, range: range) - chartFrame.minY
            }
            
            return TooltipLayer.Info.PointInfo(name: dataSet.name,
                                               value: spacedString(for: point.y),
                percent: percentValues != nil ? "\(percentValues![i])%" : nil,
                position: position,
                color: dataSet.color)
            
        }
        if let sum = sum, chartData.type == .bar {
            pointInfos.append(TooltipLayer.Info.PointInfo(name: "All",
                                                          value: "\(sum)",
                percent: nil,
                position: yPosition(for: sum) - chartFrame.minY,
                color: presentationTheme.tooltipInfoTitleColor))
        }
        return TooltipLayer.Info(selectedDate: selectedDate,
                                 xPosition: xPosition(for: selectedDate),
                                 title: tooltipTitleDateFormatter.string(from: Date(timeIntervalSince1970: selectedDate)),
                                 pointerVisible: chartData.type != .bar,
                                 pointsVisible: chartData.type == .line,
                                 pointInfos: pointInfos,
                                 tooltipGridColor: presentationTheme.axisGridColor(forChartType: chartData.type))
    }
    
    private func percentValues(at index: Int) -> [Int]?{
        var percentValues: [Int]?
        if chartData.percentage {
            let percentMultiplier = 100 / Double(dataSets.reduce(0, { $0 + $1.values[index].y }))
            let values = dataSets.enumerated().map { arg -> (Int, Int, Double) in
                let value = Double(arg.1.values[index].y) * percentMultiplier
                let floor = Int(value.rounded(.down))
                return (arg.0, floor, value - Double(floor))
            }
            var leftPercents = 100 - values.reduce(0, { $0 + $1.1 })
            
            percentValues = values.sorted(by: { $0.2 > $1.2 }).map({ args -> (Int, Int) in
                var percent = args.1
                if leftPercents > 0 {
                    leftPercents -= 1
                    percent += 1
                }
                return (args.0, percent)
            }).sorted(by: {$0.0 < $1.0}).map({ $1 })
        }
        return percentValues
    }
    // axises
    private func generateAxisesInfo(for type: AxisesType) -> AxisesTextsLayer.Info? {
        if type == .firstY && selectedYRange.current == nil {
            return nil
        }
        if type == .secondY  && secondSelectedYRange.current == nil {
            return nil
        }
        let stringsAndFrames: [String: CGRect]
        var gridInfo: AxisesTextsLayer.Info.GridInfo?
        if type == .x {
            stringsAndFrames = stringsAndFramesForXAsises()
            gridInfo = AxisesTextsLayer.Info.GridInfo(gridColor: presentationTheme.axisGridColor(forChartType: chartData.type),
                                                      gridFrames: [
                                                        CGRect(x: 0,
                                                               y: chartFrame.maxY - axisFrame.minY - 0.5,
                                                               width: axisFrame.width,
                                                               height: 1)
                ])
        }
        else {
            let isSecondAxises = type == .secondY
            let valuesAndPositions = valuesAndPositionsForAxisYGrid(isSecondAxises: isSecondAxises)
            stringsAndFrames = stringsAndFramesForYAsises(with: valuesAndPositions, isSecondAxises: isSecondAxises)
            gridInfo = yGridInfo(for: type, valuesAndPositions: valuesAndPositions)
        }
        return AxisesTextsLayer.Info(textColor: textColor(for: type),
                                     stringsAndFrames: stringsAndFrames,
                                     gridInfo: gridInfo)
    }
    
    private func yGridInfo(for type: AxisesType, valuesAndPositions: [(Int, CGFloat)]) -> AxisesTextsLayer.Info.GridInfo? {
        guard let color = gridColor(for: type) else { return nil }
        return AxisesTextsLayer.Info.GridInfo(gridColor: color,
                                              gridFrames: valuesAndPositions.map({
                                                return CGRect(x: 0,
                                                              y: $0.1 - axisFrame.minY - 0.5,
                                                              width: axisFrame.width,
                                                              height: 1)
                                              }))
    }
    
    private func gridColor(for type: AxisesType) -> UIColor? {
        if let selectedYRange = selectedYRange.current, let secondSelectedYRange = secondSelectedYRange.current,
            case let highestRange = selectedYRange.upperBound > secondSelectedYRange.upperBound ? selectedYRange : secondSelectedYRange,
            (type == .secondY ? secondSelectedYRange : selectedYRange) != highestRange
        {
            return nil
        }
        return presentationTheme.axisGridColor(forChartType: chartData.type)
    }
    
    private func textColor(for type: AxisesType) -> UIColor {
        if type == .x {
            return presentationTheme.xAxisLabelTextColor(forChartType: chartData.type)
        }
        if chartData.y_scaled {
            if type == .secondY {
                return chartData.dataSets.last!.color
            }
            return chartData.dataSets.first!.color
        }
        return presentationTheme.yAxisLabelTextColor(forChartType: chartData.type)
    }
    
    private func stringsAndFramesForXAsises() -> [String: CGRect] {
            let inseted = { (frame: CGRect) -> CGRect in
                return frame.insetBy(dx: -frame.width * 0.25 / 2, dy: 0)
            }
            var dateFrames = [Date:CGRect]()
            var selectedDates = [Date]()
            for date in allDates {
                let frame = dateFrame(for: date)
                if frame.intersects(inseted(axisFrame)) {
                    dateFrames[date] = frame.offsetBy(dx: -axisFrame.minX,
                                                      dy: -axisFrame.minY)
                    selectedDates.append(date)
                }
            }
            var i = 0
            func hide(_ date: Date, frame: CGRect, index: Int) {
                dateFrames.removeValue(forKey: date)
                selectedDates.remove(at: index)
            }
            while i < selectedDates.count {
                let topDate = selectedDates[i]
                let topFrame = dateFrames[topDate]!
                
                let leftMostDateFrame = dateFrame(for: topDate, range: xRange.lowerBound...xRange.lowerBound + selectedXRange.length)
                let rightMostDateFrame = dateFrame(for: topDate, range: xRange.upperBound - selectedXRange.length...xRange.upperBound)
                guard leftMostDateFrame.minX >= axisFrame.minX && rightMostDateFrame.maxX <= axisFrame.maxX else {
                    hide(topDate, frame: topFrame, index: i)
                    continue
                }
                var j = i + 1
                while j < selectedDates.count {
                    let date = selectedDates[j]
                    let frame = dateFrames[date]!
                    if inseted(frame).intersects(inseted(topFrame)) {
                        hide(date, frame: frame, index: j)
                    }
                    else {
                        j += 1
                    }
                }
                i += 1
            }
            return dateFrames.reduce(into: [String:CGRect](), { (result: inout [String:CGRect], val) in
                result[dateFormatter.string(from: val.0)] = val.1
            })
    }
    
    private func stringsAndFramesForYAsises(with valuesAndPositions: [(Int, CGFloat)], isSecondAxises: Bool) -> [String: CGRect] {
        let attributes = [ NSAttributedString.Key.font: font ]
        return valuesAndPositions.reduce(into: [String:CGRect]()) { (result, arg) in
            var frame = CGRect.zero
            let string = shortenedString(for: arg.0)
            frame.size = NSString(string: string).size(withAttributes: attributes)
            frame.origin.y = arg.1 - axisFrame.minY - 4 - frame.height
            if isSecondAxises {
                frame.origin.x = axisFrame.width - frame.width
            }
            if frame.minY > 0 {
                result[string] = frame
            }
        }
    }
    
    func valuesAndPositionsForAxisYGrid(isSecondAxises: Bool) -> [(Int, CGFloat)] {
        let range = (isSecondAxises ? secondSelectedYRange : selectedYRange).current!
        func calcIntervalAndFirstValue(for range: ClosedRange<Int>) -> (CGFloat, CGFloat) {
            let interval = (CGFloat(range.length) / CGFloat(6)).roundedToNextSignficant()
            let firstValue = (CGFloat(range.lowerBound) / interval).rounded(.up) * interval
            return (interval, firstValue)
        }
        let interval: CGFloat
        let firstValue: CGFloat
        if let selectedYRange = selectedYRange.current, let secondSelectedYRange = secondSelectedYRange.current,
            case let highestRange = selectedYRange.upperBound > secondSelectedYRange.upperBound ? selectedYRange : secondSelectedYRange,
            highestRange != range
        {
            let (highestInterval, highestFirstValue) = calcIntervalAndFirstValue(for: highestRange)
            let multiplier = CGFloat(range.length) / CGFloat(highestRange.length)
            interval = (highestInterval * multiplier).rounded(.up)
            firstValue = ((highestFirstValue - CGFloat(highestRange.lowerBound)) * multiplier + CGFloat(range.lowerBound)).rounded(.up)
        }
        else {
            (interval, firstValue) = calcIntervalAndFirstValue(for: range)
        }
        return stride(from: firstValue,
                      through: CGFloat(range.upperBound) + interval,
                      by: interval).compactMap { value -> (Int, CGFloat)? in
                        let value = Int(value)
                        let position = yPosition(for: value, range: range)
                        guard position >= chartFrame.minY, position <= chartFrame.maxY else { return nil }
                        return (value, position)
        }
    }
    
    private func reorderDatesByPriority() {
        class FrameInfo: CustomStringConvertible {
            let center: CGFloat
            var day: Int = -1
            var priority: CGFloat = 0
            
            init(center: CGFloat, day: Int = -1, priority: CGFloat = 0) {
                self.center = center
                self.day = day
                self.priority = priority
            }
            
            var description: String {
                return "FrameInfo: day\(day), priority: \(priority), center:\(center)"
            }
        }
        guard let xRange = xRange else { return }
        
        var spacing: CGFloat = 0.5 * dateStringSize.width
        let maxDatesCount = Int((axisFrame.width + spacing) / (dateStringSize.width + spacing))
        spacing = (axisFrame.width - CGFloat(maxDatesCount) * dateStringSize.width) / CGFloat(maxDatesCount - 1)
        
        var frameInfos = stride(from: axisFrame.minX, to: axisFrame.maxX, by: (axisFrame.width + spacing) / CGFloat(maxDatesCount)).map( { FrameInfo(center: $0 + dateStringSize.width / 2) } )
        
        allDates.sort()
        var dateFrames = Array(repeating: (0, CGFloat.infinity), count: frameInfos.count)
        for dayNumber in 0..<allDates.count{
            let position = xPosition(for: allDates[dayNumber].timeIntervalSince1970, range: xRange)
            for (i, frameInfo) in frameInfos.enumerated() {
                let distance = abs(position - frameInfo.center)
                if distance < dateFrames[i].1 {
                    dateFrames[i] = (dayNumber, distance)
                }
            }
        }
        
        let randMultiplier = { () -> CGFloat in
            return 0.7 * (1 + ((CGFloat(arc4random()) / CGFloat(UINT32_MAX)) - 0.5) / 1000)
        }
        
        for (i, dateFrame) in dateFrames.enumerated() {
            frameInfos[i].day = dateFrame.0
            frameInfos[i].priority = (100 - 0.5 - (CGFloat(allDates.count) / 2 - CGFloat(frameInfos[i].day)).magnitude / CGFloat(allDates.count)) * randMultiplier() / 0.7
        }
        
        var first = frameInfos.first!
        var last = frameInfos.last!
        var rangeLength = xRange.length
        while first.day != 0 && last.day != allDates.count && rangeLength > 1 {
            rangeLength *= 0.9
            let startRange = xRange.lowerBound...xRange.lowerBound + rangeLength
            let endRange = xRange.upperBound - rangeLength...xRange.upperBound
            let scaledFirstCenter = xPosition(for: allDates[first.day].timeIntervalSince1970, range: startRange)
            let scaledLastCenter = xPosition(for: allDates[last.day].timeIntervalSince1970, range: endRange)
            for day in 0..<first.day {
                let timestamp = allDates[day].timeIntervalSince1970
                let center = xPosition(for: timestamp, range: startRange)
                if center - dateStringSize.width / 2 >= axisFrame.minX
                    && center + dateStringSize.width + spacing <= scaledFirstCenter
                {
                    first = FrameInfo(center: xPosition(for: timestamp, range: xRange),
                                      day: day,
                                      priority: first.priority * randMultiplier())
                    frameInfos.insert(first, at: 0)
                    break
                }
            }
            for day in last.day + 1..<allDates.count {
                let timestamp = allDates[day].timeIntervalSince1970
                let center = xPosition(for: timestamp, range: endRange)
                if center + dateStringSize.width / 2 <= axisFrame.maxX
                    && scaledLastCenter + dateStringSize.width + spacing <= center
                {
                    last = FrameInfo(center: xPosition(for: timestamp, range: xRange),
                                     day: day,
                                     priority: last.priority * randMultiplier())
                    frameInfos.append(last)
                    break
                }
                
            }
        }
        
        var i = 0
        while i < frameInfos.count - 1 {
            let current = frameInfos[i]
            while case let next = frameInfos[i+1], current.day + 1 < next.day {
                let approxCenter = (current.center + next.center) / 2
                var best = (-1, CGFloat.greatestFiniteMagnitude)
                for dayNumber in current.day + 1..<next.day {
                    let position = xPosition(for: allDates[dayNumber].timeIntervalSince1970, range: xRange)
                    if (abs(position - approxCenter) < abs(best.1 - approxCenter)) {
                        best = (dayNumber, position)
                    }
                }
                frameInfos.insert(FrameInfo(center: best.1, day: best.0, priority: min(current.priority, next.priority) * randMultiplier()),
                                  at: i+1)
            }
            i += 1
        }
        while let current = frameInfos.first, current.day != 0 {
            frameInfos.insert(FrameInfo(center: xPosition(for: allDates[current.day - 1].timeIntervalSince1970, range: xRange),
                                        day: current.day - 1,
                                        priority: current.priority * randMultiplier()), at: 0)
        }
        while let current = frameInfos.last, current.day != allDates.count - 1 {
            frameInfos.append(FrameInfo(center: xPosition(for: allDates[current.day + 1].timeIntervalSince1970, range: xRange),
                                        day: current.day + 1,
                                        priority: current.priority * randMultiplier()))
        }
        let datePriorities = frameInfos.reduce(into: [Date: CGFloat](), { ( result: inout [Date: CGFloat], arg) in
            let dayDate = allDates[arg.day]
            result[dayDate] = arg.priority
        })
        allDates.sort { datePriorities[$0]! > datePriorities[$1]! }
    }
    
    private func generateDataSets() {
        dataSets = chartData.dataSets.filter { $0.selected }
        stackedDataSets = nil
        stackedPercentedDataSets = nil
        guard chartData.stacked else { return }
        if chartData.percentage {
            stackedPercentedDataSets = [(TimeInterval, [CGFloat])]()
            for i in 0..<dataSets[0].values.count {
                var values = [Int]()
                for dataSet in dataSets {
                    values.append(dataSet.values[i].y)
                }
                let multiplier = 100 / CGFloat(values.reduce(0, +))
                stackedPercentedDataSets!.append((dataSets[0].values[i].x, values.map { CGFloat($0) * multiplier }))
            }
        }
        else {
            stackedDataSets = [(TimeInterval, [Int])]()
            for i in 0..<dataSets[0].values.count {
                var values = [Int]()
                for dataSet in dataSets {
                    values.append(dataSet.values[i].y)
                }
                stackedDataSets!.append((dataSets[0].values[i].x, values))
            }
        }
    }
    
    private func calcDateStringSize() {
        dateStringSize.height = font.lineHeight
        dateStringSize.width = 0
        let attributes = [NSAttributedString.Key.font: font]
        for date in allDates {
            let string = NSString(string: dateFormatter.string(from: date))
            dateStringSize.width = max(dateStringSize.width, string.size(withAttributes: attributes).width.rounded(.up))
        }
    }
    
    private func shortenedString(for int: Int) -> String {
        if int > 9999 {
            let exp = Int(log10(Double(int)) / 3)
            if exp - 1 < units.count {
                return "\(Int(Double(int) / pow(1000, Double(exp))))\(units[exp - 1])"
            }
        }
        return "\(int)"
    }
    
    private func spacedString(for int: Int) -> String {
        var result = "\(int)"
        var index = result.count
        if index > 5 {
            while true {
                index -= 3
                if index <= 0 {
                    break
                }
                result.insert(" ", at: result.index(result.startIndex, offsetBy: index))
            }
        }
        return result
    }
}
