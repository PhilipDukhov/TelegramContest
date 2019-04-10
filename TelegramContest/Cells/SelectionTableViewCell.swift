//
//  SelectionTableViewCell.swift
//  TelegramContest
//
//  Created by Philip on 3/18/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

struct SelectableInfo: Equatable {
    var text: String
    var color: UIColor
    var selected: Bool
    
    var drawableText: String {
        if selected {
            return "✓ \(text)"
        }
        return text
    }
}


fileprivate class SelectableLayer: CALayer {
    static private let nonSelectedXInset: CGFloat = 21
    static private let font = UIFont.systemFont(ofSize: 15, weight: .semibold)
    static let height: CGFloat = 30
    
    private let textLayer = CATextLayer()
    
    var selectableInfo: SelectableInfo? {
        didSet {
            guard selectableInfo != oldValue else { return }
            setNeedsDisplay()
            setNeedsLayout()
            textLayer.string = selectableInfo?.drawableText
            if let selectableInfo = selectableInfo {
                textLayer.foregroundColor = (selectableInfo.selected ? UIColor.white : selectableInfo.color).cgColor
            }
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
        guard let selectableInfo = selectableInfo else { return }
        
        if selectableInfo.selected {
            ctx.addPath(UIBezierPath(roundedRect: bounds, cornerRadius: 6).cgPath)
            ctx.setFillColor(selectableInfo.color.cgColor)
            ctx.fillPath()
        }
        else {
            ctx.addPath(UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 6).cgPath)
            ctx.setStrokeColor(selectableInfo.color.cgColor)
            ctx.strokePath()
        }
    }
    
    private func initialize() {
        addSublayer(textLayer)
        contentsScale = UIScreen.main.scale
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.fontSize = SelectableLayer.font.pointSize
        textLayer.font = CGFont(SelectableLayer.font.fontName as CFString)
    }
    
    static func preferredFrameSize(for selectableInfo: SelectableInfo?) -> CGSize {
        guard let selectableInfo = selectableInfo else { return .zero }
        let attributes = [NSAttributedString.Key.font: font]
        let textWidth = NSString(string: selectableInfo.text).size(withAttributes: attributes).width
        return CGSize(width: textWidth + nonSelectedXInset * 2,
                      height: height)
    }
}

class SelectionTableViewCell: ParentCell {
    static private let offset: CGFloat = 9
    
    override class var reuseIdentifier: String { return "Selection" }

    @IBOutlet weak var separatorView: UIView!
    
    var selectionChangedHandler: ((Int) -> (Void))?
    
    var selectableInfos: [SelectableInfo]? {
        didSet {
            guard selectableInfos != oldValue else { return }
            guard let selectableInfos = selectableInfos, selectableInfos.count > 0 else {
                selectableLayers.removeAll()
                return
            }
            if selectableLayers.count > selectableInfos.count {
                selectableLayers.removeLast(selectableLayers.count - selectableInfos.count)
            }
            for (i, selectableInfo) in selectableInfos.enumerated() {
                let selectableLayer: SelectableLayer
                if i < selectableLayers.count {
                    selectableLayer = selectableLayers[i]
                }
                else {
                    selectableLayer = SelectableLayer()
                    selectableLayers.append(selectableLayer)
                }
                selectableLayer.selectableInfo = selectableInfo
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
        return SelectionTableViewCell.frames(for: selectableInfos,
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
    
    static private func frames(for selectableInfos: [SelectableInfo]?, firstPoint: CGPoint, maxX: CGFloat) -> [CGRect] {
        var result = [CGRect]()
        guard let selectableInfos = selectableInfos else { return result }
        let firstX = firstPoint.x
        var point = firstPoint
        for selectableInfo in selectableInfos {
            let size = SelectableLayer.preferredFrameSize(for: selectableInfo)
            if point.x + size.width > maxX {
                point.y += size.height + SelectionTableViewCell.offset
                point.x = firstX
            }
            result.append(CGRect(origin: point, size: size))
            point.x += size.width + SelectionTableViewCell.offset
        }
        return result
    }
    
    static func height(for selectableInfos: [SelectableInfo]?, maxWidth: CGFloat) -> CGFloat {
        return frames(for: selectableInfos, firstPoint: .zero, maxX: maxWidth).last?.maxY ?? 0
    }
}
