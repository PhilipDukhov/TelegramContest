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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.numberStyle = .decimal
        
        dateFormatter.dateFormat = "MMM dd"
        
        for i in 0..<365 {
            let string = NSString(string: dateFormatter.string(from: Date(timeIntervalSinceNow: TimeInterval(i * 60 * 60 * 24))))
            let size = string.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                        height: CGFloat.greatestFiniteMagnitude),
                                           attributes: dateLabelAttributes(),
                                           context: nil).size
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
        
        context.setFillColor(UIColor(hex: "#E1E2E3").cgColor)
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
        
        let xPositionForValue = { (value: TimeInterval) in
            return self.lineWidth / 2 + CGFloat(value - minDataEntry.x) / CGFloat(maxDataEntry.x - minDataEntry.x) * (chartFrame.size.width - self.lineWidth)
        }
        let yPositionForValue = { (value: Int) in
            return (1 - CGFloat(value - minDataEntry.y) / CGFloat(maxDataEntry.y - minDataEntry.y)) * (chartFrame.size.height - self.lineWidth)
        }
        
//        x axis
        var dateFrames = selectedDates.reduce(into: [Date:(CGRect, CGFloat)]()) { (result: inout [Date:(CGRect, CGFloat)], date) in
            result[date] = (CGRect(origin: CGPoint(x: xPositionForValue(date.timeIntervalSince1970),
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
            NSString(string: dateFormatter.string(from: date)).draw(in: frame, withAttributes: dateLabelAttributes(withAlpha: alpha))
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
            context.setFillColor(UIColor(hex: "#F3F3F3").cgColor)
            if Int(y) != minDataEntry.y {
                context.fill(frame)
            }
            NSString(string: numberFormatter.string(from: y as NSNumber)!).draw(at: CGPoint(x: 0, y: frame.minY - 4 - dateStringSize.height), withAttributes: dateLabelAttributes())
        }
        
//        chart
        for dataSet in chartData {
            context.setStrokeColor(dataSet.color.cgColor)
            context.setLineJoin(.round)
            context.setFlatness(0.1)
            context.setLineCap(.round)
            
            let points = dataSet.values.filter( {selectedXRange.contains($0.x)} )
                .map({ CGPoint(x: xPositionForValue($0.x),
                               y: lineWidth / 2 + yPositionForValue($0.y)) })
            context.addLines(between: points)
            context.strokePath()
            
//            selected date
            if let selectedDate = selectedDate {
                context.setFillColor(UIColor(hex: "#CFD1D2").cgColor)
                context.fill(CGRect(x: xPositionForValue(selectedDate),
                                    y: 0,
                                    width: 1,
                                    height: chartFrame.height))
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
    
    private func dateLabelAttributes(withAlpha alpha: CGFloat = 1) -> [NSAttributedString.Key : Any] {
        return [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 152/255, green: 158/255, blue: 163/255, alpha: alpha),
            .paragraphStyle: paragraphStyle
        ]
    }
    
    @objc private func tapHandler(_ gestureRecognizer: UITapGestureRecognizer) {
        let x = gestureRecognizer.location(in: self).x
        let timestamp = TimeInterval((x - lineWidth / 2) / (bounds.width - lineWidth) * CGFloat(selectedXRange.upperBound - selectedXRange.lowerBound)) + selectedXRange.lowerBound
        selectedDate = datePriorities.keys.map({($0, ($0.timeIntervalSince1970 - timestamp).magnitude)}).sorted(by: {$0.1 < $1.1}).first!.0.timeIntervalSince1970
    }
}
