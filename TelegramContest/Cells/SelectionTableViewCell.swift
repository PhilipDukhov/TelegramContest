//
//  SelectionTableViewCell.swift
//  TelegramContest
//
//  Created by Philip on 3/18/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit


fileprivate class SelectableLayer: CALayer {
    static private let nonSelectedXInset: CGFloat = 21
    static private let font = UIFont.systemFont(ofSize: 15, weight: .semibold)
    static let height: CGFloat = 30
    
    private let textLayer = CATextLayer()
    
    var chartDataSet: ChartDataSet? {
        didSet {
            guard chartDataSet != oldValue else { return }
            update()
        }
    }
    
    override init() {
        super.init()
        initialize()
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        var frame = CGRect(origin: .zero, size: textLayer.preferredFrameSize())
        frame.origin.y = (bounds.height - frame.size.height) / 2
        frame.origin.x = (bounds.width - frame.size.width) / 2
        textLayer.frame = frame
    }
    
    override func draw(in ctx: CGContext) {
        guard let chartDataSet = chartDataSet else { return }
        
        if chartDataSet.selected {
            ctx.addPath(UIBezierPath(roundedRect: bounds, cornerRadius: 6).cgPath)
            ctx.setFillColor(chartDataSet.color.cgColor)
            ctx.fillPath()
        }
        else {
            ctx.addPath(UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 6).cgPath)
            ctx.setStrokeColor(chartDataSet.color.cgColor)
            ctx.strokePath()
        }
    }
    
    func update() {
        guard let chartDataSet = chartDataSet else { return }
        setNeedsDisplay()
        setNeedsLayout()
        textLayer.string = chartDataSet.selected ? "✓ \(chartDataSet.name)" : chartDataSet.name
        textLayer.foregroundColor = (chartDataSet.selected ? UIColor.white : chartDataSet.color).cgColor
    }
    
    private func initialize() {
        addSublayer(textLayer)
        contentsScale = UIScreen.main.scale
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.setUIFont(SelectableLayer.font)
        actions = [
            "bounds": NSNull(),
            "position": NSNull()
        ]
        textLayer.actions = actions
    }
    
    static func preferredFrameSize(for chartDataSet: ChartDataSet?) -> CGSize {
        guard let chartDataSet = chartDataSet else { return .zero }
        let attributes = [NSAttributedString.Key.font: font]
        let textWidth = NSString(string: chartDataSet.name).size(withAttributes: attributes).width
        return CGSize(width: textWidth + nonSelectedXInset * 2,
                      height: height)
    }
}

class SelectionTableViewCell: ParentCell {
    static private let offset: CGFloat = 9
    
    override class var reuseIdentifier: String { return "Selection" }

    @IBOutlet weak var separatorView: UIView!
    
    var selectionChangedHandler: ((Int) -> (Void))?
    
    var chartDataSets: [ChartDataSet]? {
        didSet {
            guard chartDataSets != oldValue else { return }
            guard let chartDataSets = chartDataSets, chartDataSets.count > 0 else {
                selectableLayers.removeAll()
                return
            }
            if selectableLayers.count > chartDataSets.count {
                selectableLayers.removeLast(selectableLayers.count - chartDataSets.count)
            }
            for (i, chartDataSet) in chartDataSets.enumerated() {
                let selectableLayer: SelectableLayer
                if i < selectableLayers.count {
                    selectableLayer = selectableLayers[i]
                }
                else {
                    selectableLayer = SelectableLayer()
                    selectableLayers.append(selectableLayer)
                }
                selectableLayer.chartDataSet = chartDataSet
            }
            setNeedsLayout()
        }
    }
    
    fileprivate var selectableLayers = [SelectableLayer]() {
        didSet {
            oldValue.forEach {
                if !selectableLayers.contains($0) {
                    $0.removeFromSuperlayer()
                }
            }
            selectableLayers.forEach {
                if !oldValue.contains($0) {
                    contentView.layer.addSublayer($0)
                }
            }
        }
    }
    
    override var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            separatorView.backgroundColor = presentationTheme.selectionSeparatorColor
        }
    }
    
    private var currentFrames: [CGRect] {
        return SelectionTableViewCell.frames(for: chartDataSets,
                                             firstPoint: CGPoint(x: layoutMargins.left, y: 5),
                                             maxX: bounds.width - layoutMargins.left - layoutMargins.right)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        separatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:))))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let frames = currentFrames
        for (i, selectableLayer) in selectableLayers.enumerated() {
            selectableLayer.frame = frames[i]
        }
    }
    
    @objc private func tapHandler(_ gestureRecognizer: UITapGestureRecognizer) {
        let frames = currentFrames
        let point = gestureRecognizer.location(in: self)
        var nearestControl: (Int?, CGFloat) = (nil, .greatestFiniteMagnitude)
        for (i, frame) in frames.enumerated() {
            if let distance = frame.distanceFromRectMid(to: point), distance < nearestControl.1 {
                nearestControl = (i, distance)
            }
        }
        if let i = nearestControl.0 {
            selectionChangedHandler?(i)
        }
    }
    
    func update() {
        selectableLayers.forEach { $0.update() }
    }
    
    static private func frames(for chartDataSets: [ChartDataSet]?, firstPoint: CGPoint, maxX: CGFloat) -> [CGRect] {
        var result = [CGRect]()
        guard let chartDataSets = chartDataSets else { return result }
        let firstX = firstPoint.x
        var point = firstPoint
        for chartDataSet in chartDataSets {
            let size = SelectableLayer.preferredFrameSize(for: chartDataSet)
            if point.x + size.width > maxX {
                point.y += size.height + SelectionTableViewCell.offset
                point.x = firstX
            }
            result.append(CGRect(origin: point, size: size))
            point.x += size.width + SelectionTableViewCell.offset
        }
        return result
    }
    
    static func height(for selectableInfos: [ChartDataSet]?, maxWidth: CGFloat) -> CGFloat {
        return frames(for: selectableInfos, firstPoint: .zero, maxX: maxWidth).last?.maxY ?? 0
    }
}
