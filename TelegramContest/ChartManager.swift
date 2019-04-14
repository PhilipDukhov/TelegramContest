//
//  ChartManager.swift
//  TelegramContest
//
//  Created by Philip on 4/14/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit


fileprivate let daySeconds: TimeInterval = 60 * 60 * 24
fileprivate let animationDuration: TimeInterval = 0.33
let lineWidth: CGFloat = 1.5

class CachedDateFormatter: DateFormatter {
    private var cachedStrings = [Date:String]()
    
    func clearCached() {
        cachedStrings.removeAll()
    }
    
    override func string(from date: Date) -> String {
        let date = Date(timeIntervalSince1970: (date.timeIntervalSince1970 / daySeconds).rounded(.down) * daySeconds)
        if let cachedString = cachedStrings[date] {
            return cachedString
        }
        let result = super.string(from: date)
        cachedStrings[date] = result
        return result
    }
}

struct Segment {
    var start: TimeInterval
    var end: TimeInterval
    var lenth: TimeInterval {
        return end - start
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
    
    let numberFormatter = NumberFormatter()
    let dateFormatter = CachedDateFormatter()
    let titleDateFormatter = CachedDateFormatter()
    
    var chartFrame: CGRect!
    var axisFrame: CGRect!
    
    private var pendingChartData: ChartData?
    private var _chartData: ChartData!
    var chartData: ChartData {
        set {
            if updating {
                pendingChartData = newValue
                return
            }
            defer {
                setNeedsUpdate()
            }
            let newData = _chartData != newValue
            _chartData = newValue
            dataSets = chartData.dataSets.filter { $0.selected }
            guard dataSets.count > 0 else { return }
            
            var minX: TimeInterval = .greatestFiniteMagnitude
            var maxX: TimeInterval = 0
            var datesSet = Set<Date>()
            for dataEntry in chartData.dataSets.first!.values {
                minX = min(minX, dataEntry.x)
                maxX = max(maxX, dataEntry.x)
                datesSet.insert(Date(timeIntervalSince1970: dataEntry.x))
            }
            dateFormatter.clearCached()
            titleDateFormatter.clearCached()
            allDates = Array(datesSet)
            calcDateStringSize()
            
            xRange = minX...maxX
            totalDaysNumber = Calendar.current.dateComponents([.day],
                                                              from: Date(timeIntervalSince1970: minX),
                                                              to: Date(timeIntervalSince1970: maxX)).day ?? 0
            if newData {
                selectedYRange.current = nil
                secondSelectedYRange.current = nil
            }
            if axisFrame != nil {
                reorderDatesByPriority()
            }
        }
        get { return _chartData }
    }
    var xRange: ClosedRange<TimeInterval>!
    
    private var pendingVisibleSegment: Segment?
    private var _visibleSegment: Segment!
    var visibleSegment: Segment {
        set {
            if updating {
                pendingVisibleSegment = newValue
                return
            }
            _visibleSegment = newValue
            let dayTimestampForRangePart = { (range: ClosedRange<TimeInterval>, part: TimeInterval) in
                return range.lowerBound + range.length * part
            }
            selectedXRange = max(newValue.start, dayTimestampForRangePart(xRange, visibleSegment.start))...dayTimestampForRangePart(xRange, newValue.end)
            setNeedsUpdate()
        }
        get { return _visibleSegment }
    }
    var selectedXRange: ClosedRange<TimeInterval>!
    var presentationTheme: PresentationTheme! {
        didSet {
            if _chartData != nil {
                setNeedsUpdate()
            }
        }
    }
    var allDates: [Date]!
    var dateStringSize = CGSize.zero
    
    var totalDaysNumber = 0
    var datePriorities: [Date: CGFloat]!
    
    let font = UIFont.systemFont(ofSize: 11)
    var dataSets: [ChartDataSet]!
    var selectedYRange = AnimatingRangeInfo()
    var secondSelectedYRange = AnimatingRangeInfo()
    var borderedXRange: ClosedRange<TimeInterval>!
    
    var selectedDate: TimeInterval? {
        didSet {
            setNeedsUpdate()
        }
    }
    
    var needsRedrawToAnimate = false
    
    var axisesInfos: [AxisesTextsLayer.Info?]!
    var valuesInfo: ValuesLayer.Info!
    var tooltipInfo: TooltipLayer.Info?
    
    var queue = DispatchQueue(label: "calculations")
    
    weak var delegate: ChartManagerDelegate?
    
    init() {
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.numberStyle = .decimal
        
        dateFormatter.dateFormat = "MMM dd"
        titleDateFormatter.dateFormat = "EEE, dd MMM YYYY"
    }
    
    func update(chartFrame: CGRect, axisFrame: CGRect) {
        self.chartFrame = chartFrame
        self.axisFrame = axisFrame
        reorderDatesByPriority()
        setNeedsUpdate()
    }
    
    private var needsUpdate = false
    private var updating = false
    func setNeedsUpdate() {
        guard !needsUpdate, axisFrame != nil else { return }
        needsUpdate = true
        queue.async {
            self.updateValues()
        }
    }
    private func updateValues() {
        guard !updating, needsUpdate || selectedYRange.animating || secondSelectedYRange.animating else { return }
        needsUpdate = false
        updating = true
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
            if let dataSet = chartData.dataSets.first, dataSet.selected {
                selectedYRange.calculateCurrentRange(withFinal: range(from: dataSet.values, minZero: false))
            }
            else {
                selectedYRange.current = nil
            }
            if let dataSet = chartData.dataSets.last, dataSet.selected {
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
            else if let stackedDataSets = chartData.stackedDataSets {
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
        updating = false
        if let pendingChartData = pendingChartData {
            chartData = pendingChartData
            self.pendingChartData = nil
        }
        if let pendingVisibleSegment = pendingVisibleSegment {
            visibleSegment = pendingVisibleSegment
            self.pendingVisibleSegment = nil
        }
        DispatchQueue.main.async {
            self.delegate?.chartManagerUpdatedValues(self)
        }
        queue.async {
            self.updateValues()
        }
    }
    
    func setSelectedDate(from point: CGPoint) {
        let timestamp = TimeInterval((point.x - lineWidth / 2 - axisFrame.minX) / (axisFrame.width - lineWidth) * CGFloat(selectedXRange.length)) + selectedXRange.lowerBound
        selectedDate = allDates.map({($0, ($0.timeIntervalSince1970 - timestamp).magnitude)}).sorted(by: {$0.1 < $1.1}).first!.0.timeIntervalSince1970
        tooltipInfo = generateTooltipInfo()
        if chartData.type == .bar {
            valuesInfo = generateValuesInfo()
        }
    }
    
    private func generateValuesInfo() -> ValuesLayer.Info? {
        switch chartData.type {
        case .area:
            if let stackedPercentedDataSets = chartData.stackedPercentedDataSets {
                var points = Array<[CGPoint]>(repeating: [CGPoint](), count: dataSets.count - 1)
                
                var point = CGPoint.zero
                for (x, values) in stackedPercentedDataSets where borderedXRange.contains(x) {
                    point.x = xPosition(for: x).rounded()
                    point.y = chartFrame.height
                    var sum: CGFloat = 0
                    for (j, value) in values.enumerated() where j != values.count - 1 {
                        sum += value
                        point.y = ((1 - sum / 100) * (chartFrame.height - lineWidth)).rounded()
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
                return .area([(UIColor.clear.cgColor, points[0])] + zip(dataSets.map({ $0.color.cgColor }), points[1...]))
            }
            
        case .line:
            return .line(dataSets.map({ dataSet -> (CGColor, [CGPoint]) in
                let range = (chartData.y_scaled && dataSet != chartData.dataSets[0] ? secondSelectedYRange : selectedYRange).current!
                return (dataSet.color.cgColor,
                        dataSet.values.filter( {borderedXRange.contains($0.x)} )
                            .map({ CGPoint(x: xPosition(for: $0.x),
                                           y: lineWidth / 2 + yPosition(for: $0.y, range: range)) }))
                
            }))
            
        case .bar:
            let step = xPosition(for: dataSets[0].values[1].x) - xPosition(for: dataSets[0].values[0].x)
            var rects = Array<[CGRect]>(repeating: [CGRect](), count: dataSets.count)
            var selectedRects = [[CGRect]]()
            
            if let stackedDataSets = chartData.stackedDataSets {
                var frame = CGRect.zero
                frame.size.width = step
                for (x, values) in stackedDataSets where borderedXRange.contains(x) {
                    frame.origin.x = (xPosition(for: x) - step / 2).roundedScreenScaled(.down)
                    frame.origin.y = chartFrame.height
                    var sum = 0
                    for (j, value) in values.enumerated() {
                        sum += value
                        frame.size.height = frame.origin.y
                        frame.origin.y = yPosition(for: sum).roundedScreenScaled
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
                var frame = CGRect.zero
                frame.size.width = step
                for (i, dataSet) in dataSets.enumerated() {
                    for value in dataSet.values where borderedXRange.contains(value.x) {
                        frame.origin.x = xPosition(for: value.x) - step / 2
                        frame.origin.y = yPosition(for: value.y)
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
            return .bar(zip(colors, rects).map{ ($0, $1) })
            
        }
        return nil
    }
    
    private func xPosition(for value: TimeInterval, range: ClosedRange<TimeInterval>? = nil) -> CGFloat {
        let range = range ?? selectedXRange!
        return axisFrame.minX + lineWidth / 2 + CGFloat(value - range.lowerBound) / CGFloat(range.length) * (axisFrame.width - lineWidth)
    }
    
    private func yPosition(for value: Int, range: ClosedRange<Int>? = nil) -> CGFloat {
        let range = range ?? selectedYRange.current!
        return axisFrame.minY + (1 - CGFloat(value - range.lowerBound) / CGFloat(range.length)) * (axisFrame.height - lineWidth)
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
        
        var pointInfos = dataSets.enumerated().map { arg -> TooltipLayer.Info.PointInfo in
            let (i, dataSet) = arg
            let point = dataSet.values[index]
            let position: CGFloat
            if sum != nil {
                sum! += point.y
                position = yPosition(for: sum!)
            }
            else {
                let range = (chartData.y_scaled && dataSet != chartData.dataSets[0] ? secondSelectedYRange : selectedYRange).current!
                position = yPosition(for: point.y, range: range)
            }
            return TooltipLayer.Info.PointInfo(name: dataSet.name,
                                               value: "\(point.y)",
                percent: percentValues != nil ? "\(percentValues![i])%" : nil,
                position: position,
                color: dataSet.color)
            
        }
        if let sum = sum, chartData.type == .bar {
            pointInfos.append(TooltipLayer.Info.PointInfo(name: "All",
                                                          value: "\(sum)",
                percent: nil,
                position: yPosition(for: sum),
                color: presentationTheme.tooltipInfoTitleColor))
        }
        return TooltipLayer.Info(selectedDate: selectedDate,
                                 xPosition: xPosition(for: selectedDate),
                                 title: titleDateFormatter.string(from: Date(timeIntervalSince1970: selectedDate)),
                                 pointerVisible: chartData.type != .bar,
                                 pointsVisible: chartData.type == .line,
                                 pointInfos: pointInfos,
                                 tooltipGridColor: presentationTheme.axisGridColor(forChartType: chartData.type))
    }
    
    private enum AxisesType {
        case x
        case firstY
        case secondY
        
        static var all: [AxisesType] { return [ .x, .firstY, .secondY ] }
    }
    // axises
    private func generateAxisesInfo(for type: AxisesType) -> AxisesTextsLayer.Info? {
        if type == .firstY && selectedYRange.current == nil {
            return nil
        }
        if type == .secondY  && secondSelectedYRange.current == nil {
            return nil
        }
        let stringsAndFrames = self.stringsAndFrames(for: type)
        return AxisesTextsLayer.Info(textColor: textColor(for: type),
                                     stringsAndFrames: stringsAndFrames,
                                     gridInfo: gridInfo(for: type, stringsAndFrames: stringsAndFrames))
    }
    
    private func gridInfo(for type: AxisesType, stringsAndFrames: [String: CGRect]) -> AxisesTextsLayer.Info.GridInfo? {
        if type == .x {
            return AxisesTextsLayer.Info.GridInfo(gridColor: presentationTheme.axisGridColor(forChartType: chartData.type),
                                                  gridFrames: [
                                                    CGRect(x: chartFrame.minX,
                                                           y: chartFrame.height - 1,
                                                           width: axisFrame.width,
                                                           height: 1)
                ])
        }
        guard let color = gridColor(for: type) else { return nil }
        return AxisesTextsLayer.Info.GridInfo(gridColor: color,
                                              gridFrames: stringsAndFrames.map({
                                                CGRect(x: 0,
                                                       y: $0.1.maxY + 4,
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
        if type != .x, chartData.y_scaled {
            if type == .secondY {
                return chartData.dataSets.last!.color
            }
            return chartData.dataSets.first!.color
        }
        return presentationTheme.axisLabelTextColor
    }
    
    private func stringsAndFrames(for type: AxisesType) -> [String: CGRect] {
        if type == .x {
            let inseted = { (frame: CGRect) -> CGRect in
                return frame.insetBy(dx: -frame.width * 0.25 / 2, dy: 0)
            }
            var dateFrames = [Date:CGRect]()
            var selectedDates = [Date]()
            for date in allDates {
                var frame = dateFrame(for: date)
                if frame.intersects(inseted(axisFrame)) {
                    frame.origin.x -= axisFrame.minX
                    dateFrames[date] = frame
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
        let isSecondAxises = type == .secondY
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
        
        let attributes = [ NSAttributedString.Key.font: font ]
        var result = [String:CGRect]()
        for y in stride(from: firstValue,
                        through: CGFloat(range.upperBound),
                        by: interval)
        {
            let y = Int(y)
            let position = yPosition(for: y, range: range)
            if position > axisFrame.minX {
                var frame = CGRect.zero
                let string = numberFormatter.string(from: y as NSNumber)!
                frame.size = NSString(string: string).size(withAttributes: attributes)
                frame.origin.y = position - 4 - frame.height
                if isSecondAxises {
                    frame.origin.x = axisFrame.width - frame.width
                }
                result[string] = frame
            }
        }
        return result
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
        
        var frameInfos = stride(from: axisFrame.minX, to: axisFrame.width, by: (axisFrame.width + spacing) / CGFloat(maxDatesCount)).map( { FrameInfo(center: $0 + dateStringSize.width / 2) } )
        
        var dateFrames = Array(repeating: (0, CGFloat.infinity), count: frameInfos.count)
        for dayNumber in stride(from: 0, to: totalDaysNumber, by: 1) {
            let position = xPosition(for: xRange.lowerBound + TimeInterval(dayNumber) * daySeconds, range: xRange)
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
            frameInfos[i].priority = (100 - 0.5 - (CGFloat(totalDaysNumber) / 2 - CGFloat(frameInfos[i].day)).magnitude / CGFloat(totalDaysNumber)) * randMultiplier() / 0.7
        }
        
        var first = frameInfos.first!
        var last = frameInfos.last!
        var rangeLength = xRange.length
        while first.day != 0 && last.day != totalDaysNumber && rangeLength > 1 {
            rangeLength *= 0.9
            let startRange = xRange.lowerBound...xRange.lowerBound + rangeLength
            let endRange = xRange.upperBound - rangeLength...xRange.upperBound
            let scaledFirstCenter = xPosition(for: xRange.lowerBound + TimeInterval(first.day) * daySeconds, range: startRange)
            let scaledLastCenter = xPosition(for: xRange.lowerBound + TimeInterval(last.day) * daySeconds, range: endRange)
            for day in 0..<first.day {
                let timestamp = xRange.lowerBound + TimeInterval(day) * daySeconds
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
            for day in last.day + 1...totalDaysNumber {
                let timestamp = xRange.lowerBound + TimeInterval(day) * daySeconds
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
                    let position = xPosition(for: xRange.lowerBound + TimeInterval(dayNumber) * daySeconds, range: xRange)
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
            frameInfos.insert(FrameInfo(center: xPosition(for: xRange.lowerBound + (TimeInterval(current.day) - 1) * daySeconds, range: xRange),
                                        day: current.day - 1,
                                        priority: current.priority * randMultiplier()), at: 0)
        }
        while let current = frameInfos.last, current.day != totalDaysNumber {
            frameInfos.append(FrameInfo(center: xPosition(for: xRange.lowerBound + (TimeInterval(current.day) + 1) * daySeconds, range: xRange),
                                        day: current.day + 1,
                                        priority: current.priority * randMultiplier()))
        }
        let datePriorities = frameInfos.reduce(into: [Date: CGFloat](), { ( result: inout [Date: CGFloat], arg) in
            let dayDate = Date(timeIntervalSince1970: xRange.lowerBound + TimeInterval(arg.day * 60 * 60 * 24))
            result[dayDate] = arg.priority
        })
        allDates.sort { datePriorities[$0]! > datePriorities[$1]! }
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
}
