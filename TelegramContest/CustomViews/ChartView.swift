//
//  ChartView.swift
//  TelegramContest
//
//  Created by Philip on 3/19/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

fileprivate extension ClosedRange where Bound : Numeric {
    var length: Bound {
        return upperBound - lowerBound
    }
}

fileprivate extension CGFloat
{
    /// Rounds the number to the nearest multiple of it's order of magnitude, rounding away from zero if halfway.
    func roundedToNextSignficant() -> CGFloat
    {
        guard
            !isInfinite,
            !isNaN,
            self != 0
            else { return self }
        
        let d = ceil(log10(self < 0 ? -self : self))
        let pw = 1 - Int(d)
        let magnitude = pow(10.0, CGFloat(pw))
        let shifted = (self * magnitude).rounded(.up)
        return (shifted / magnitude).rounded()
    }
}

struct Segment {
    var start: TimeInterval
    var end: TimeInterval
    var lenth: TimeInterval {
        return end - start
    }
}

fileprivate let daySeconds: TimeInterval = 60 * 60 * 24
fileprivate let animationDuration: TimeInterval = 0.33
fileprivate let datesSectionHeight: CGFloat = 18
fileprivate let lineWidth: CGFloat = 1.5
fileprivate let numberOfLabels = 6
fileprivate let selectedInset = CGPoint(x: 9, y: 4)
fileprivate let selectedOffsetY: CGFloat = 7

class ChartView: UIView {
    
    var chartData: [ChartDataSet]? {
        didSet {
            guard chartData != oldValue else {return}
            defer {
                setNeedsDisplay()
            }
            guard let chartData = chartData, chartData.count > 0 else { return }
            if oldValue == nil || Set(oldValue!).intersection(chartData).count == 0 {
                chartDataAlpha = 1
                selectedYRange = nil
                visibleDateAlphas = nil
                selectedDate = nil
                oldSelectedDate = nil
            }
            else {
                chartDataAlpha = 0
                oldChartData = oldValue
            }
            
            var minX = chartData.first!.values.first!.x
            var maxX = chartData.first!.values.first!.x
            for dataSet in chartData {
                for dataEntry in dataSet.values {
                    minX = min(minX, dataEntry.x)
                    maxX = max(maxX, dataEntry.x)
                }
            }
            
            xRange = minX...maxX
            totalDaysNumber = Calendar.current.dateComponents([.day],
                                                              from: Date(timeIntervalSince1970: minX),
                                                              to: Date(timeIntervalSince1970: maxX)).day ?? 0
            
            calculateDatePriorities()
        }
    }
    
    var visibleSegment: Segment = Segment(start: 0, end: 1) {
        didSet { setNeedsDisplay() }
    }
    var selectedDate: TimeInterval? {
        didSet {
            guard selectedDate != oldValue else { return }
            oldSelectedDate = oldValue
            selectedDateInfoFrame = nil
            setNeedsDisplay()
        }
    }
    var selectedDateChangedHandler: ((TimeInterval?)->())?
    var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            setNeedsDisplay()
        }
    }
    
    private let numberFormatter = NumberFormatter()
    private let dateFormatter = DateFormatter()
    private var dateStringSize: CGSize!
    
    private var xRange: ClosedRange<TimeInterval>!
    private var selectedYRange: ClosedRange<Int>!
    private var selectedXRange: ClosedRange<TimeInterval>!
    private var borderedXRange: ClosedRange<TimeInterval>!
    private var totalDaysNumber: Int!
    private var datePriorities: [Date: CGFloat]!
    private var visibleDateAlphas: [Date: CGFloat]!
    
    private var selectedDateInfoFrame: CGRect?
    
    private var oldSelectedDate: TimeInterval? {
        didSet { oldSelectedDateAlpha = selectedDateAlpha }
    }
    private var oldSelectedDateAlpha: CGFloat = 0
    private var selectedDateAlpha: CGFloat = 0
    
    
    private var oldChartData: [ChartDataSet]? {
        didSet { oldChartDataAlpha = 1 }
    }
    private var oldChartDataAlpha: CGFloat = 0
    private var chartDataAlpha: CGFloat = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.numberStyle = .decimal
        
        dateFormatter.dateFormat = "MMM dd"
        
        for i in 0..<365 {
            let string = NSString(string: dateFormatter.string(from: Date(timeIntervalSinceNow: TimeInterval(i) * daySeconds)))
            let size = string.size(withAttributes: dateLabelAttributes())
            if dateStringSize == nil {
                dateStringSize = size
            }
            else {
                dateStringSize.width = max(size.width, dateStringSize.width).rounded(.up)
                dateStringSize.height = max(size.height, dateStringSize.height).rounded(.up)
            }
        }
        
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:))))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        calculateDatePriorities()
    }
    
    @objc private func tapHandler(_ gestureRecognizer: UITapGestureRecognizer) {
        let point = gestureRecognizer.location(in: self)
        defer {
            selectedDateAlpha = 0
            selectedDateChangedHandler?(selectedDate)
        }
        if selectedDateInfoFrame?.contains(point) == true {
            selectedDate = nil
            return
        }
        let timestamp = TimeInterval((point.x - lineWidth / 2) / (bounds.width - lineWidth) * CGFloat(selectedXRange!.length)) + selectedXRange.lowerBound
        selectedDate = datePriorities.keys.map({($0, ($0.timeIntervalSince1970 - timestamp).magnitude)}).sorted(by: {$0.1 < $1.1}).first!.0.timeIntervalSince1970
    }
    
    private var lastDrawDate: Date?
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let date = Date()
        guard
            let chartData = chartData,
            let context = UIGraphicsGetCurrentContext()
            else { return }
        context.setLineJoin(.round)
        context.setFlatness(0.1)
        context.setLineCap(.round)
        var needsRedrawToAnimate = false
        
        context.setLineWidth(lineWidth)
        let chartFrame = rect.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: datesSectionHeight, right: 0))
        
        context.setFillColor(presentationTheme.yAxisZeroLineColor.cgColor)
        context.fill(CGRect(x: 0, y: chartFrame.maxY, width: rect.width, height: 1))
        
        let dayTimestampForRangePart = { (range: ClosedRange<TimeInterval>, part: TimeInterval) in
            return range.lowerBound + (range.length) * part
        }
        selectedXRange = max(visibleSegment.start, dayTimestampForRangePart(xRange, visibleSegment.start))...dayTimestampForRangePart(xRange, visibleSegment.end)

        var minDataEntry = ChartDataEntry(x: selectedXRange.lowerBound, y: Int.max)
        var maxDataEntry = ChartDataEntry(x: selectedXRange.upperBound, y: Int.min)
        
        var borderDates = (xRange.lowerBound, xRange.upperBound)
        for dataSet in chartData {
            for dataEntry in dataSet.values where !selectedXRange.contains(dataEntry.x) {
                if dataEntry.x < selectedXRange.lowerBound {
                    borderDates.0 = max(borderDates.0, dataEntry.x)
                }
                else {
                    borderDates.1 = min(borderDates.1, dataEntry.x)
                }
            }
        }
        borderedXRange = borderDates.0...borderDates.1
        
        var selectedDates = [Date]()
        for dataSet in chartData {
            for dataEntry in dataSet.values {
                if borderedXRange.contains(dataEntry.x) {
                    minDataEntry.y = min(minDataEntry.y, dataEntry.y)
                    maxDataEntry.y = max(maxDataEntry.y, dataEntry.y)
                }
                selectedDates.append(Date(timeIntervalSince1970: dataEntry.x))
            }
        }
        selectedDates = Array(Set(selectedDates)).sorted()
        
        minDataEntry.y = max(minDataEntry.y - (maxDataEntry.y - minDataEntry.y) / 20, 0)
        if maxDataEntry.y - (maxDataEntry.y - minDataEntry.y) * 4 < 0 {
            minDataEntry.y = 0
        }
        maxDataEntry.y += (maxDataEntry.y - minDataEntry.y) / 20
        if let selectedYRange = selectedYRange {
            let koeff = max(selectedYRange.length, maxDataEntry.y - minDataEntry.y) / 20
            let diff = abs((selectedYRange.length) - (maxDataEntry.y - minDataEntry.y))
            if koeff < diff {
                maxDataEntry.y = selectedYRange.upperBound + (maxDataEntry.y - selectedYRange.upperBound) * koeff / diff
                minDataEntry.y = selectedYRange.lowerBound + (minDataEntry.y - selectedYRange.lowerBound) * koeff / diff
                needsRedrawToAnimate = true
            }
        }
        selectedYRange = minDataEntry.y...maxDataEntry.y
        
        // x axis
        let inseted = { (frame: CGRect) -> CGRect in
            return frame.insetBy(dx: -frame.width * 0.25 / 2, dy: 0)
        }
        var alphaStep: CGFloat = 1/30
        if let lastDrawDate = lastDrawDate, -lastDrawDate.timeIntervalSinceNow < animationDuration {
            alphaStep = max(alphaStep, CGFloat(-lastDrawDate.timeIntervalSinceNow / animationDuration))
        }
        let defaultAlpha: CGFloat = visibleDateAlphas == nil ? 1 : 0
        var dateFrames = selectedDates.reduce(into: [Date:(CGRect, CGFloat)]()) { (result: inout [Date:(CGRect, CGFloat)], date) in
            result[date] = (dateFrame(for: date), visibleDateAlphas?[date] ?? defaultAlpha)
        }
        for (i, date) in selectedDates.enumerated().reversed() {
            if !dateFrames[date]!.0.intersects(inseted(bounds)) {
                selectedDates.remove(at: i)
                dateFrames[date] = nil
            }
        }
        selectedDates.sort { datePriorities[$0]! > datePriorities[$1]! }
        var i = 0
        func hide(_ date: Date, frame: CGRect, index: Int) {
            if let oldAlpha = visibleDateAlphas?[date], oldAlpha > alphaStep {
                dateFrames[date] = (frame, max(0, oldAlpha - alphaStep))
            }
            else {
                dateFrames.removeValue(forKey: date)
            }
            selectedDates.remove(at: index)
        }
        func show(_ date: Date, frame: CGRect) {
            if let alpha = dateFrames[date]?.1, visibleDateAlphas?[date] == alpha {
                dateFrames[date] = (frame, min(1, alpha + alphaStep))
            }
        }
        while i < selectedDates.count {
            let topDate = selectedDates[i]
            let (topFrame, _) = dateFrames[topDate]!
            
            let leftMostFrame = dateFrame(for: topDate, range: xRange.lowerBound...xRange.lowerBound + selectedXRange.length)
            let rightMostFrame = dateFrame(for: topDate, range: xRange.upperBound - selectedXRange.length...xRange.upperBound)
            guard leftMostFrame.minX > bounds.minX && rightMostFrame.maxX < bounds.maxX else {
                hide(topDate, frame: topFrame, index: i)
                continue
            }
            show(topDate, frame: topFrame)
            var j = i + 1
            while j < selectedDates.count {
                let date = selectedDates[j]
                let (frame, _) = dateFrames[date]!
                if inseted(frame).intersects(inseted(topFrame)) {
                    hide(date, frame: frame, index: j)
                }
                else {
                    j += 1
                    show(date, frame: frame)
                }
            }
            i += 1
        }
        
        for (date, (frame, alpha)) in dateFrames {
            context.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            NSString(string: dateFormatter.string(from: date)).draw(in: frame, withAttributes: dateLabelAttributes(alpha: alpha))
        }
        visibleDateAlphas = dateFrames.mapValues({$1})
        needsRedrawToAnimate = needsRedrawToAnimate || visibleDateAlphas.values.contains(where: {$0 != 1})
        
        // y axis
        let interval = (CGFloat(selectedYRange.length) / CGFloat(numberOfLabels)).roundedToNextSignficant()
        
        for y in stride(from: CGFloat(minDataEntry.y),
                        through: CGFloat(maxDataEntry.y),//(floor(CGFloat(maxDataEntry.y) / interval) * interval).nextUp,
                        by: interval)
        {
            let y = Int(y)
            let frame = CGRect(x: 0,
                               y: yPosition(for: y),
                               width: rect.width,
                               height: 1)
            context.setFillColor(presentationTheme.yAxisOtherLineColor.cgColor)
            if min(abs(yPosition(for: y) - yPosition(for: minDataEntry.y)),
                   abs(yPosition(for: y) - yPosition(for: maxDataEntry.y))) > 3
            {
                context.fill(frame)
            }
            let point = CGPoint(x: 0, y: frame.minY - 4 - dateStringSize.height)
            if point.y > chartFrame.minX {
                NSString(string: numberFormatter.string(from: y as NSNumber)!).draw(at: point, withAttributes: dateLabelAttributes())
            }
        }
        
        // chart
        if let oldChartData = oldChartData {
            oldChartDataAlpha = max(0, oldChartDataAlpha - alphaStep * 2)
            chartDataAlpha = min(1, chartDataAlpha + alphaStep * 2)
            if oldChartDataAlpha > 0 && chartDataAlpha < 1 {
                draw(Array(Set(oldChartData).subtracting(chartData)), in: context, alpha: oldChartDataAlpha)
                draw(Array(Set(chartData).subtracting(oldChartData)), in: context, alpha: chartDataAlpha)
                draw(Array(Set(chartData).intersection(oldChartData)), in: context)
                needsRedrawToAnimate = true
            }
            else {
                self.oldChartData = nil
                draw(chartData, in: context)
            }
        }
        else {
            draw(chartData, in: context)
        }
        // selected date
        if let oldSelectedDate = oldSelectedDate {
            oldSelectedDateAlpha = max(0, oldSelectedDateAlpha - alphaStep)
            if oldSelectedDateAlpha > 0 {
                needsRedrawToAnimate = true
                draw(oldSelectedDate, in: context, chartFrame: chartFrame, alpha: oldSelectedDateAlpha)
            }
            else {
                self.oldSelectedDate = nil
            }
        }
        if let selectedDate = selectedDate {
            needsRedrawToAnimate = needsRedrawToAnimate || selectedDateAlpha < 1
            selectedDateAlpha = min(1, selectedDateAlpha + alphaStep)
            
            selectedDateInfoFrame = draw(selectedDate, in: context, chartFrame: chartFrame, alpha: selectedDateAlpha)
        }
        if needsRedrawToAnimate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.setNeedsDisplay()
            }
        }
        lastDrawDate = Date()
        print(-date.timeIntervalSinceNow)
    }
    
    // privates
    
    private func draw(_ chartData: [ChartDataSet], in context: CGContext, alpha: CGFloat = 1) {
        for dataSet in chartData {
            let points = dataSet.values.filter( {borderedXRange.contains($0.x)} )
                .map({ CGPoint(x: xPosition(for: $0.x),
                               y: lineWidth / 2 + yPosition(for: $0.y)) })
            context.setStrokeColor(dataSet.color.withAlphaComponent(alpha).cgColor)
            context.addLines(between: points)
            context.strokePath()
        }
    }
    
    @discardableResult private func draw(_ selectedDate: TimeInterval, in context: CGContext, chartFrame: CGRect, alpha: CGFloat) -> CGRect? {
        guard let chartData = chartData else {return nil}
        let date = Date(timeIntervalSince1970: selectedDate)
        let xPosition = self.xPosition(for: selectedDate)
        var pointInfos = [(UIColor, ChartDataEntry)]()
        var maxWidth: CGFloat = 0
        var yEntries = [selectedYRange.lowerBound, selectedYRange.upperBound]
        for dataSet in chartData {
            if let point = dataSet.values.first(where: {$0.x == selectedDate}) {
                pointInfos.append((dataSet.color, point))
                maxWidth = max(maxWidth, NSString(string: "\(point.y)").size(withAttributes: dateLabelAttributes()).width)
                yEntries.append(point.y)
            }
        }
        let yPositions = yEntries.map({yPosition(for: $0)}).sorted()
        let cornerRadius: CGFloat = 3
        var pointerLineFrame = CGRect.zero
        var rect = CGRect()
        rect.size = CGSize(width: max(95, (maxWidth + selectedInset.x * 1.5) * 2), height: max(2, CGFloat(chartData.count)) * (dateStringSize.height + selectedInset.y / 2) + selectedInset.y * 2)
        rect.origin.x = xPosition - rect.width / 2
        let spaceNeeded = rect.width + selectedOffsetY * 2
        func updateRectPositionNearBorder() {
            if rect.maxX > chartFrame.maxX {
                rect.origin.x = max(min(rect.origin.x, chartFrame.maxX - rect.width), pointerLineFrame.maxX - rect.width)
            }
            else if rect.minX < chartFrame.minX {
                rect.origin.x = min(max(rect.origin.x, chartFrame.minX), pointerLineFrame.minX)
            }
        }
        if yPositions[1] - yPositions[0] > spaceNeeded {
            rect.origin.y = selectedOffsetY
            pointerLineFrame = CGRect(x: xPosition - 0.5,
                                      y: rect.maxY,
                                      width: 1,
                                      height: chartFrame.height - rect.maxY)
            updateRectPositionNearBorder()
            if rect.minX + cornerRadius > pointerLineFrame.minX {
                pointerLineFrame.origin.y = sqrt(pow(cornerRadius, 2) - pow(pointerLineFrame.minX - rect.minX - cornerRadius, 2)) + rect.maxY - cornerRadius
            }
            else if rect.maxX - cornerRadius < pointerLineFrame.maxX {
                pointerLineFrame.origin.y = sqrt(pow(cornerRadius, 2) - pow(pointerLineFrame.maxX - rect.maxX + cornerRadius, 2)) + rect.maxY - cornerRadius
            }
            pointerLineFrame.size.height = chartFrame.height - pointerLineFrame.minY
        }
        else if yPositions.count > 2 && yPositions.last! - yPositions[yPositions.count - 2] > spaceNeeded {
            rect.origin.y = chartFrame.height - rect.height - selectedOffsetY
            pointerLineFrame = CGRect(x: xPosition - 0.5,
                                      y: 0,
                                      width: 1,
                                      height: rect.minY)
            updateRectPositionNearBorder()
            if rect.minX + cornerRadius > pointerLineFrame.minX {
                pointerLineFrame.size.height = -sqrt(pow(cornerRadius, 2) - pow(pointerLineFrame.minX - rect.minX - cornerRadius, 2)) + rect.minY + cornerRadius
            }
            else if rect.maxX - cornerRadius < pointerLineFrame.maxX {
                pointerLineFrame.size.height = -sqrt(pow(cornerRadius, 2) - pow(pointerLineFrame.maxX - rect.maxX + cornerRadius, 2)) + rect.minY + cornerRadius
            }
        }
        else {
            var maxRange: (CGFloat, CGFloat) = (0, 0)
            for i in 0..<yPositions.count - 1 {
                if maxRange.1 - maxRange.0 < yPositions[i + 1] - yPositions[i] {
                    maxRange = (yPositions[i], yPositions[i + 1])
                }
            }
            
            rect.origin.y = (maxRange.1 + maxRange.0 - rect.height) / 2
            pointerLineFrame = CGRect(x: xPosition - 0.5,
                                      y: 0,
                                      width: 1,
                                      height: chartFrame.height)
            if maxRange.1 - maxRange.0 < rect.width + selectedOffsetY * 2 {
                if xPosition < chartFrame.width / 2 {
                    rect.origin.x = xPosition + selectedOffsetY
                }
                else {
                    rect.origin.x = xPosition - selectedOffsetY - rect.width
                }
            }
            else {
                updateRectPositionNearBorder()
            }
        }
        context.setFillColor(presentationTheme.selectedDatePointerLineColor.withAlphaComponent(alpha).cgColor)
        context.fill(pointerLineFrame)
        
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        if presentationTheme.gradientFirstPointColor != presentationTheme.gradientLastPointColor {
            let gradientRatio: CGFloat = 120/145
            let degree: CGFloat = atan(1/gradientRatio)
            
            let c: CGFloat
            if rect.width / rect.height > gradientRatio {
                c = (rect.height * gradientRatio) - rect.width
            }
            else if rect.width / rect.height < gradientRatio {
                c = rect.height - (rect.width / gradientRatio)
            }
            else {
                c = 0
            }
            let a = sin(alpha) * c
            let startPoint = CGPoint(x: sin(degree) * -a,
                                     y: cos(degree) * a)
            
            context.saveGState()
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [presentationTheme.gradientFirstPointColor.withAlphaComponent(alpha).cgColor, presentationTheme.gradientLastPointColor.withAlphaComponent(alpha).cgColor] as CFArray,
                                      locations: [0.0, 1.0])!
            context.addPath(path.cgPath)
            context.clip()
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: rect.minX + startPoint.x, y: rect.minY + startPoint.y),
                                       end: CGPoint(x: rect.maxX, y: rect.maxY),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            context.restoreGState()
        }
        else {
            context.setFillColor(presentationTheme.gradientFirstPointColor.withAlphaComponent(alpha).cgColor)
            path.fill()
        }
        
        let dayString = NSString(string: dateFormatter.string(from: date))
        let dayStringFrame = CGRect(origin: CGPoint(x: rect.minX + selectedInset.x, y: rect.minY + selectedInset.y),
                                    size: dayString.size(withAttributes: dateLabelAttributes()))
        dayString.draw(in: dayStringFrame, withAttributes: dateLabelAttributes(with: presentationTheme.selectedDateTextColor, alpha: alpha))
        
        let yearString = NSString(string: "\(Calendar.current.component(.year, from: date))")
        yearString.draw(at: CGPoint(x: dayStringFrame.minX, y: dayStringFrame.maxY + selectedInset.y / 2),
                        withAttributes: dateLabelAttributes(with: presentationTheme.selectedDateTextColor, alpha: alpha))
        
        for (i, (color, point)) in pointInfos.enumerated() {
            let string = NSString(string: "\(point.y)")
            let attributes = dateLabelAttributes(with: color, alpha: alpha)
            var frame = CGRect()
            frame.size = string.size(withAttributes: attributes)
            frame.origin = CGPoint(x: rect.maxX - selectedInset.x - frame.width,
                                   y: rect.minY + selectedInset.y + (selectedInset.y / 2 + frame.height) * CGFloat(i))
            string.draw(in: frame, withAttributes: attributes)
            
            frame.size = CGSize(width: 6, height: 6)
            frame.origin.x = xPosition - frame.width / 2
            frame.origin.y = lineWidth / 2 + yPosition(for: point.y) - frame.height / 2
            context.setFillColor(presentationTheme.cellBackgroundColor.withAlphaComponent(alpha).cgColor)
            context.fillEllipse(in: frame)
            context.strokeEllipse(in: frame)
        }
        return rect
    }
    
    private func calculateDatePriorities() {
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
                return "FrameInfo: day\(day), priority\(priority), center:\(center)"
            }
        }
        guard let totalDaysNumber = totalDaysNumber, let xRange = xRange else { return }
        
        var spacing: CGFloat = 0.5 * dateStringSize.width
        let maxDatesCount = Int((bounds.width + spacing) / (dateStringSize.width + spacing))
        spacing = (bounds.width - CGFloat(maxDatesCount) * dateStringSize.width) / CGFloat(maxDatesCount - 1)
        
        var frameInfos = stride(from: 0, to: bounds.width, by: (bounds.width + spacing) / CGFloat(maxDatesCount)).map( { FrameInfo(center: $0 + dateStringSize.width / 2) } )
        
        var dateFrames = Array(repeating: (0, CGFloat.infinity), count: frameInfos.count)
//        dateFrames[0] = (0, 0)
//        dateFrames[frameInfos.count - 1] = (totalDaysNumber, 0)
        for dayNumber in stride(from: 0, to: totalDaysNumber, by: 1) {
            let position = xPosition(for: xRange.lowerBound + TimeInterval(dayNumber) * daySeconds, range: xRange)
            for (i, frameInfo) in frameInfos.enumerated() {
                let distance = abs(position - frameInfo.center)
                if distance < dateFrames[i].1 {
                    dateFrames[i] = (dayNumber, distance)
                }
            }
        }
        
        let randValue = { () -> CGFloat in
            return ((CGFloat(arc4random()) / CGFloat(UINT32_MAX)) - 0.5) / 1000
        }
        
        for (i, dateFrame) in dateFrames.enumerated() {
            frameInfos[i].day = dateFrame.0
            frameInfos[i].priority = (100 - 0.5 - (CGFloat(totalDaysNumber) / 2 - CGFloat(frameInfos[i].day)).magnitude / CGFloat(totalDaysNumber)) * (1 + randValue())
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
                frameInfos.insert(FrameInfo(center: best.1, day: best.0, priority: min(current.priority, next.priority) * 0.7 * (1 + randValue())),
                                  at: i+1)
            }
            i += 1
        }
        while let current = frameInfos.first, current.day != 0 {
            frameInfos.insert(FrameInfo(center: xPosition(for: (TimeInterval(current.day) - 1) * daySeconds, range: xRange),
                                        day: current.day - 1,
                                        priority: current.priority * 0.7 * (1 + randValue())), at: 0)
        }
        while let current = frameInfos.last, current.day != totalDaysNumber {
            frameInfos.append(FrameInfo(center: xPosition(for: (TimeInterval(current.day) + 1) * daySeconds, range: xRange),
                                        day: current.day + 1,
                                        priority: current.priority * 0.7 * (1 + randValue())))
        }
        datePriorities = frameInfos.reduce(into: [Date: CGFloat](), { ( result: inout [Date: CGFloat], arg) in
            let dayDate = Date(timeIntervalSince1970: xRange.lowerBound + TimeInterval(arg.day * 60 * 60 * 24))
            result[dayDate] = arg.priority
        })
    }
    
    private let paragraphStyle: NSParagraphStyle = {
        let paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paraStyle.alignment = .center
        return paraStyle
    }()
    
    private func dateLabelAttributes(with color: UIColor? = nil, alpha: CGFloat = 1) -> [NSAttributedString.Key : Any] {
        let color = color ?? presentationTheme?.axisLabelTextColor ?? .white
        return [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: color.withAlphaComponent(alpha),
            .paragraphStyle: paragraphStyle
        ]
    }
    
    private func xPosition(for value: TimeInterval, range: ClosedRange<TimeInterval>? = nil) -> CGFloat {
        let range = range ?? selectedXRange!
        return lineWidth / 2 + CGFloat(value - range.lowerBound) / CGFloat(range.length) * (bounds.width - lineWidth)
    }
    
    private func yPosition(for value: Int) -> CGFloat {
        return (1 - CGFloat(value - selectedYRange.lowerBound) / CGFloat(selectedYRange.length)) * (bounds.height - datesSectionHeight - lineWidth)
    }
    
    private func dateFrame(for date: Date, range: ClosedRange<TimeInterval>? = nil) -> CGRect {
        return CGRect(origin: CGPoint(x: xPosition(for: date.timeIntervalSince1970, range: range) - dateStringSize.width / 2,
                                      y: bounds.maxY - dateStringSize.height),
                      size: dateStringSize)
    }
}
