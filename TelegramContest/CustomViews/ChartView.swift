//
//  ChartView.swift
//  TelegramContest
//
//  Created by Philip on 3/19/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

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
        let shifted = (self * magnitude).rounded()
        return shifted / magnitude
    }
}

struct Segment {
    var start: TimeInterval
    var end: TimeInterval
    var lenth: TimeInterval {
        return end - start
    }
}

class ChartView: UIView {
    private static let datesSectionHeight: CGFloat = 18
    private let lineWidth: CGFloat = 1.5
    private static let numberOfLabels = 6
    private let selectedInset = CGPoint(x: 9, y: 4)
    private let selectedOffsetY: CGFloat = 7
    
    var chartData: [ChartDataSet]? {
        didSet {
            guard let chartData = chartData, chartData.count > 0 else { return }
            
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
            setNeedsDisplay()
        }
    }
    
    var visibleSegment: Segment = Segment(start: 0, end: 1) {
        didSet { setNeedsDisplay() }
    }
    var selectedDate: TimeInterval? {
        didSet {
            selectedDateInfoFrame = nil
            setNeedsDisplay()
        }
    }
    var presentationTheme: PresentationTheme = PresentationTheme.dayTheme {
        didSet {
            guard presentationTheme.isDark != oldValue.isDark else { return }
            setNeedsDisplay()
        }
    }
    
    private let numberFormatter = NumberFormatter()
    private let dateFormatter = DateFormatter()
    private var dateStringSize: CGSize!
    
    private var xRange: ClosedRange<TimeInterval>!
    private var selectedXRange: ClosedRange<TimeInterval>!
    private var totalDaysNumber: Int!
    private var datePriorities: [Date: CGFloat]!
    
    private var selectedDateInfoFrame: CGRect?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.numberStyle = .decimal
        
        dateFormatter.dateFormat = "MMM dd"
        
        for i in 0..<365 {
            let string = NSString(string: dateFormatter.string(from: Date(timeIntervalSinceNow: TimeInterval(i * 60 * 60 * 24))))
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
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard
            let chartData = chartData,
            let context = UIGraphicsGetCurrentContext()
            else { return }
        
        context.setLineWidth(lineWidth)
        let chartFrame = rect.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: ChartView.datesSectionHeight, right: 0))
        
        context.setFillColor(presentationTheme.yAxisZeroLineColor.cgColor)
        context.fill(CGRect(x: 0, y: chartFrame.maxY, width: rect.width, height: 1))
        
        let dayTimestampForRangePart = { (range: ClosedRange<TimeInterval>, part: TimeInterval) in
            return range.lowerBound + (range.upperBound - range.lowerBound) * part
        }
        selectedXRange = dayTimestampForRangePart(xRange, visibleSegment.start)...dayTimestampForRangePart(xRange, visibleSegment.end)

        var minDataEntry = ChartDataEntry(x: selectedXRange.lowerBound, y: Int.max)
        var maxDataEntry = ChartDataEntry(x: selectedXRange.upperBound, y: Int.min)
        
        var borderDates = (xRange.lowerBound, xRange.upperBound)
        
        var selectedDates = [Date]()
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
        selectedXRange = borderDates.0...borderDates.1
        for dataSet in chartData {
            for dataEntry in dataSet.values {
                if selectedXRange.contains(dataEntry.x) {
                    minDataEntry.y = min(minDataEntry.y, dataEntry.y)
                    maxDataEntry.y = max(maxDataEntry.y, dataEntry.y)
                }
                selectedDates.append(Date(timeIntervalSince1970: dataEntry.x))
            }
        }
        selectedDates = Array(Set(selectedDates)).sorted()
        
        let range = maxDataEntry.y - minDataEntry.y
        maxDataEntry.y += range / 20
        minDataEntry.y = max(minDataEntry.y - range / 20, 0)
        
        let xPositionForValue = { (value: TimeInterval, viewWidth: CGFloat) in
            return self.lineWidth / 2 + CGFloat(value - minDataEntry.x) / CGFloat(maxDataEntry.x - minDataEntry.x) * (chartFrame.size.width - self.lineWidth - viewWidth)
        }
        let yPositionForValue = { (value: Int) in
            return (1 - CGFloat(value - minDataEntry.y) / CGFloat(maxDataEntry.y - minDataEntry.y)) * (chartFrame.size.height - self.lineWidth)
        }
        
//        x axis
        var dateFrames = selectedDates.reduce(into: [Date:(CGRect, CGFloat)]()) { (result: inout [Date:(CGRect, CGFloat)], date) in
            result[date] = (CGRect(origin: CGPoint(x: xPositionForValue(date.timeIntervalSince1970, self.dateStringSize.width),
                                                   y: chartFrame.maxY + (ChartView.datesSectionHeight - dateStringSize.height) / 2),
                                   size: dateStringSize),
                            1)
        }
        selectedDates.sort { datePriorities[$0]! > datePriorities[$1]! }
        var i = 0
        let inseted = { (frame: CGRect) -> CGRect in
            return frame.insetBy(dx: -frame.width * 0.25, dy: 0)
        }
        while i < selectedDates.count {
            let topDate = selectedDates[i]
            let (topFrame, _) = dateFrames[topDate]!
            var j = i + 1
            while j < selectedDates.count {
                let date = selectedDates[j]
                let (frame, alpha) = dateFrames[date]!
                guard inseted(frame).intersects(inseted(topFrame)) else { j += 1; continue }
                if frame.intersects(topFrame) {
                    dateFrames.removeValue(forKey: date)
                    selectedDates.remove(at: j)
                }
                else {
                    j += 1
                    dateFrames[date] = (frame, min(alpha, 1 - 2 * inseted(frame).intersection(inseted(topFrame)).width / frame.width))
                }
            }
            i += 1
        }
        
        for (date, (frame, alpha)) in dateFrames {
            NSString(string: dateFormatter.string(from: date)).draw(in: frame, withAttributes: dateLabelAttributes(alpha: alpha))
        }
        
//        y axis
        let interval = (CGFloat(range) / CGFloat(ChartView.numberOfLabels)).roundedToNextSignficant()
        maxDataEntry.y = Int(interval * (CGFloat(maxDataEntry.y) / interval).rounded(.up))
        minDataEntry.y = Int(interval * (CGFloat(minDataEntry.y) / interval).rounded(.down))
        
        for y in stride(from: CGFloat(minDataEntry.y),
                        through: (floor(CGFloat(maxDataEntry.y) / interval) * interval).nextUp,
                        by: interval)
        {
            let frame = CGRect(x: 0,
                               y: yPositionForValue(Int(y)),
                               width: rect.width,
                               height: 1)
            context.setFillColor(presentationTheme.yAxisOtherLineColor.cgColor)
            if Int(y) != minDataEntry.y && Int(y) != maxDataEntry.y {
                context.fill(frame)
            }
            NSString(string: numberFormatter.string(from: y as NSNumber)!).draw(at: CGPoint(x: 0, y: frame.minY - 4 - dateStringSize.height), withAttributes: dateLabelAttributes())
        }
        
        // chart
        context.setLineJoin(.round)
        context.setFlatness(0.1)
        context.setLineCap(.round)
        for dataSet in chartData {
            let points = dataSet.values.filter( {selectedXRange.contains($0.x)} )
                .map({ CGPoint(x: xPositionForValue($0.x, 0),
                               y: lineWidth / 2 + yPositionForValue($0.y)) })
            context.setStrokeColor(dataSet.color.cgColor)
            context.addLines(between: points)
            context.strokePath()
        }
        
        
        // selected date
        if let selectedDate = selectedDate {
            let date = Date(timeIntervalSince1970: selectedDate)
            let xPosition = xPositionForValue(selectedDate, 1)
            var pointInfos = [(UIColor, ChartDataEntry)]()
            var maxWidth: CGFloat = 0
            var yEntries = [minDataEntry.y, maxDataEntry.y]
            for dataSet in chartData {
                if let point = dataSet.values.first(where: {$0.x == selectedDate}) {
                    pointInfos.append((dataSet.color, point))
                    maxWidth = max(maxWidth, NSString(string: "\(point.y)").size(withAttributes: dateLabelAttributes()).width)
                    yEntries.append(point.y)
                }
            }
            let yPositions = yEntries.map({yPositionForValue($0)}).sorted()
            
            let pointerLineFrame: CGRect
            var rect = CGRect()
            rect.size = CGSize(width: max(95, (maxWidth + selectedInset.x * 1.5) * 2), height: max(2, CGFloat(chartData.count)) * (dateStringSize.height + selectedInset.y / 2) + selectedInset.y * 2)
            rect.origin.x = xPosition - rect.width / 2
            let spaceNeeded = rect.size.width + selectedOffsetY * 2
            if yPositions[1] - yPositions[0] > spaceNeeded {
                rect.origin.y = selectedOffsetY
                pointerLineFrame = CGRect(x: xPosition - 0.5,
                                          y: rect.midY,
                                          width: 1,
                                          height: chartFrame.height - rect.midY)
                if rect.maxX > chartFrame.maxX {
                    rect.origin.x = max(min(rect.origin.x, chartFrame.maxX - rect.width), pointerLineFrame.maxX - rect.width)
                }
                else if rect.minX < chartFrame.minX {
                    rect.origin.x = min(max(rect.origin.x, chartFrame.minX), pointerLineFrame.minX)
                }
            }
            else if yPositions.count > 2 && yPositions.last! - yPositions[yPositions.count - 2] > spaceNeeded {
                rect.origin.y = chartFrame.height - rect.height - selectedOffsetY
                pointerLineFrame = CGRect(x: xPosition - 0.5,
                                          y: 0,
                                          width: 1,
                                          height: rect.midY)
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
                if maxRange.1 - maxRange.0 < rect.size.width + selectedOffsetY * 2 {
                    if xPosition < chartFrame.width / 2 {
                        rect.origin.x = xPosition + selectedOffsetY
                    }
                    else {
                        rect.origin.x = xPosition - selectedOffsetY - rect.width
                    }
                }
            }
            context.setFillColor(presentationTheme.selectedDatePointerLineColors.cgColor)
            context.fill(pointerLineFrame)
            
            let gradientRatio: CGFloat = 120/145
            let alpha: CGFloat = abs(atan(1/gradientRatio))
            let betta = CGFloat.pi / 2 - alpha
            
            var startPoint = CGPoint.zero
            if rect.size.width / rect.size.height > gradientRatio {
                let c = rect.size.width - (tan(betta) * rect.size.height)
                let a = sin(alpha) * c
                let b = cos(alpha) * c
                let h = a * b / c
                let ca = a * a / c
                startPoint = CGPoint(x: ca, y: -h)
            }
            else if rect.size.width / rect.size.height < gradientRatio {
                let c = rect.size.height - (tan(alpha) * rect.size.width)
                let a = sin(alpha) * c
                let b = cos(alpha) * c
                let h = a * b / c
                let ca = a * a / c
                startPoint = CGPoint(x: -ca, y: h)
            }
            selectedDateInfoFrame = rect
            
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 3)
            if presentationTheme.gradientFirstPointColor != presentationTheme.gradientLastPointColor {
                context.saveGState()
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: [presentationTheme.gradientFirstPointColor.cgColor, presentationTheme.gradientLastPointColor.cgColor] as CFArray,
                                          locations: [0.0, 1.0])!
                context.addPath(path.cgPath)
                context.clip()
                context.drawLinearGradient(gradient,
                                           start: CGPoint(x: rect.minX + startPoint.x, y: rect.minY + startPoint.y),
                                           end: CGPoint(x: rect.maxX, y: rect.maxY),
                                           options: [])
                context.restoreGState()
            }
            else {
                context.setFillColor(presentationTheme.gradientFirstPointColor.cgColor)
                path.fill()
            }
            
            let dayString = NSString(string: dateFormatter.string(from: date))
            let dayStringFrame = CGRect(origin: CGPoint(x: rect.minX + selectedInset.x, y: rect.minY + selectedInset.y),
                                        size: dayString.size(withAttributes: dateLabelAttributes()))
            dayString.draw(in: dayStringFrame, withAttributes: dateLabelAttributes(with: presentationTheme.selectedDateTextColor))
            
            let yearString = NSString(string: "\(Calendar.current.component(.year, from: date))")
            yearString.draw(at: CGPoint(x: dayStringFrame.minX, y: dayStringFrame.maxY + selectedInset.y / 2),
                            withAttributes: dateLabelAttributes(with: presentationTheme.selectedDateTextColor))
            
            for (i, (color, point)) in pointInfos.enumerated() {
                let string = NSString(string: "\(point.y)")
                let attributes = dateLabelAttributes(with: color)
                var frame = CGRect()
                frame.size = string.size(withAttributes: attributes)
                frame.origin = CGPoint(x: rect.maxX - selectedInset.x - frame.width,
                                       y: rect.minY + selectedInset.y + (selectedInset.y / 2 + frame.height) * CGFloat(i))
                string.draw(in: frame, withAttributes: attributes)
                
                frame.size = CGSize(width: 6, height: 6)
                frame.origin.x = xPosition - frame.width / 2
                frame.origin.y = lineWidth / 2 + yPositionForValue(point.y) - frame.height / 2
                context.setFillColor(presentationTheme.cellBackgroundColor.cgColor)
                context.fillEllipse(in: frame)
                context.strokeEllipse(in: frame)
            }
        }
    }
    
    private func calculateDatePriorities() {
        guard let totalDaysNumber = totalDaysNumber, let xRange = xRange else { return }
        let maxDatesCount = Int(frame.width / (dateStringSize.width * 1.5))
        let step = CGFloat(totalDaysNumber) / CGFloat(maxDatesCount - 1)
        
        let randValue = { () -> CGFloat in
            return ((CGFloat(arc4random()) / CGFloat(UINT32_MAX)) - 0.5) / 1000
        }
        var array: [(Int, CGFloat)] = stride(from: 0, to: CGFloat(totalDaysNumber) + step, by: step).map {
            let x = CGFloat(totalDaysNumber) / 2 - (CGFloat(totalDaysNumber) / 2 - $0).magnitude
            let priority = (100 - x / CGFloat(totalDaysNumber)) * (1 + randValue())
            return (Int($0.rounded()), priority)
        }
        
        var i = 0
        while i < array.count - 1 {
            let current = array[i]
            while case let next = array[i+1], current.0 + 1 < next.0 {
                let newIndex = (current.0 + next.0) / 2
                let newPriority = min(current.1, next.1) / 2 * (1 + randValue())
                array.insert((newIndex, newPriority),
                             at: i + 1)
            }
            i += 1
        }
        datePriorities = array.reduce(into: [Date: CGFloat](), { ( result: inout [Date: CGFloat], arg) in
            let dayDate = Date(timeIntervalSince1970: xRange.lowerBound + TimeInterval(arg.0 * 60 * 60 * 24))
            result[dayDate] = arg.1
        })
    }
    
    private let paragraphStyle: NSParagraphStyle = {
        let paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paraStyle.alignment = .center
        return paraStyle
    }()
    
    private func dateLabelAttributes(with color: UIColor? = nil, alpha: CGFloat = 1) -> [NSAttributedString.Key : Any] {
        let color = color ?? presentationTheme.axisLabelTextColor
        return [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: color.withAlphaComponent(alpha),
            .paragraphStyle: paragraphStyle
        ]
    }
    
    @objc private func tapHandler(_ gestureRecognizer: UITapGestureRecognizer) {
        let point = gestureRecognizer.location(in: self)
        if selectedDateInfoFrame?.contains(point) == true {
            selectedDate = nil
            return
        }
        let timestamp = TimeInterval((point.x - lineWidth / 2) / (bounds.width - lineWidth) * CGFloat(selectedXRange.upperBound - selectedXRange.lowerBound)) + selectedXRange.lowerBound
        selectedDate = datePriorities.keys.map({($0, ($0.timeIntervalSince1970 - timestamp).magnitude)}).sorted(by: {$0.1 < $1.1}).first!.0.timeIntervalSince1970
    }
}
