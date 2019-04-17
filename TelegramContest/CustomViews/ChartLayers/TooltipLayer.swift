//
//  TooltipLayer.swift
//  TelegramContest
//
//  Created by Philip on 4/10/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

private let contentWidth: CGFloat = 145
private let textLayerYOffset: CGFloat = 17
private let percentXOffset: CGFloat = 6

class TooltipLayer: CALayer {
    struct Info: Equatable, Hashable {
        struct PointInfo: Equatable, Hashable {
            let name: String
            let value: String
            let percent: String?
            let position: CGFloat
            let color: UIColor
        }
        
        let selectedDate: TimeInterval
        let xPosition: CGFloat
        let title: String
        let pointerVisible: Bool
        let pointsVisible: Bool
        let pointInfos: [PointInfo]
        let tooltipGridColor: UIColor
    }
    
    private var oldInfo: Info?
    var info: Info? {
        didSet {
            guard info != oldValue else {return}
            oldInfo = oldValue
            setNeedsLayout()
        }
    }
    var lineWidth: CGFloat!
    var onLayoutSubviews: (()->())?
    
    let contentLayer = CALayer()
    private var pointerLayer = CALayer()
    private var titleLayer: CATextLayer!
    private var infoLayers = [(CATextLayer?, CATextLayer, CATextLayer, CALayer)]()
    var arrowFrame: CGRect? {
        if !isHidden && !contentLayer.isHidden {
            return CGRect(x: contentLayer.bounds.width - 16, y: 9, width: 4, height: 8)
        }
        return nil
    }
    
    private let animationPrefix = "cstm"
    
    static private let font = UIFont.systemFont(ofSize: 11)
    static private let titleFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
    static private let percentStringWidth: CGFloat = {
        var result: CGFloat = 0
        for i in 10...99 {
            result = max(result, NSString(string: "\(i)%").size(withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .semibold)]).width)
        }
        return result
    }()
    
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
    
    private func initialize() {
        [ self, pointerLayer, contentLayer ].forEach { $0.contentsScale = UIScreen.main.scale }
        
        addSublayer(pointerLayer)
        
        contentLayer.cornerRadius = 5
        contentLayer.frame = CGRect(x: 0, y: 0, width: contentWidth, height: 0)
        contentLayer.delegate = self
        addSublayer(contentLayer)
        
        titleLayer = createTextLayer(font: TooltipLayer.titleFont)
        titleLayer.frame = CGRect(x: 10, y: 6, width: contentWidth - 18, height: TooltipLayer.titleFont.lineHeight)
        contentLayer.addSublayer(titleLayer)
    }
    
    var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            setNeedsDisplay()
            contentLayer.setNeedsDisplay()
            infoLayers.forEach {
                $0.0?.foregroundColor = presentationTheme.tooltipInfoTitleColor.cgColor
                $0.1.foregroundColor = presentationTheme.tooltipInfoTitleColor.cgColor
            }
            titleLayer.foregroundColor = presentationTheme.tooltipInfoTitleColor.cgColor
            contentLayer.backgroundColor = presentationTheme.tooltipBackground.cgColor
        }
    }
    
    override func layoutSublayers() {
        defer {
            onLayoutSubviews?()
        }
        super.layoutSublayers()
        guard let info = info else {
            isHidden = true
            return
        }
        contentLayer.setNeedsDisplay()
        titleLayer.string = info.title
        if infoLayers.count > info.pointInfos.count {
            infoLayers[info.pointInfos.count...].forEach {
                [ $0.0, $0.1, $0.2, $0.3 ].forEach {
                    $0?.removeFromSuperlayer()
                }
            }
            infoLayers.removeLast(infoLayers.count - info.pointInfos.count)
        }
        while infoLayers.count < info.pointInfos.count {
            let layers: (CATextLayer?, CATextLayer, CATextLayer, CALayer)
                = (nil,
                   createTextLayer(font: TooltipLayer.font, alignmentMode: .left),
                   createTextLayer(font: TooltipLayer.titleFont, alignmentMode: .right),
                   createPointLayer())
            layers.1.foregroundColor = presentationTheme.tooltipInfoTitleColor.cgColor
            infoLayers.append(layers)
        }
        var newFrame = titleLayer.frame
        newFrame.size.width = contentWidth - titleLayer.frame.minX * 2
        var minYPosition = CGFloat.greatestFiniteMagnitude
        for (i, pointInfo) in info.pointInfos.enumerated() {
            newFrame.origin.y += textLayerYOffset
            var (percentLayer, nameLayer, valueLayer, pointLayer) = infoLayers[i]
            
            if let percent = pointInfo.percent {
                if percentLayer == nil {
                    percentLayer = createTextLayer(font: TooltipLayer.titleFont, alignmentMode: .right)
                    percentLayer!.foregroundColor = presentationTheme.tooltipInfoTitleColor.cgColor
                    infoLayers[i] = (percentLayer, nameLayer, valueLayer, pointLayer)
                }
                percentLayer!.string = percent
                newFrame.size.width = TooltipLayer.percentStringWidth
                percentLayer!.frame = newFrame
                newFrame.origin.x = newFrame.maxX + percentXOffset
                newFrame.size.width = contentWidth - newFrame.minX - titleLayer.frame.minX
            }
            else if let percentLayer = percentLayer {
                percentLayer.removeFromSuperlayer()
                infoLayers[i] = (nil, nameLayer, valueLayer, pointLayer)
            }
            
            nameLayer.string = pointInfo.name
            nameLayer.frame = newFrame
            valueLayer.string = pointInfo.value
            valueLayer.foregroundColor = pointInfo.color.cgColor
            valueLayer.frame = newFrame
            minYPosition = min(minYPosition, pointInfo.position)
            pointLayer.isHidden = !info.pointsVisible
            if info.pointsVisible {
                pointLayer.setPointer(CGPoint(x: info.xPosition, y: pointInfo.position),
                                      side: 6,
                                      lineWidth: lineWidth,
                                      lineColor: pointInfo.color,
                                      backgroundColor: presentationTheme.cellBackgroundColor)
            }
            if pointInfo.percent != nil {
                newFrame.origin.x = titleLayer.frame.minX
                newFrame.size.width = contentWidth - titleLayer.frame.minX * 2
            }
        }
        var contentFrame = CGRect(x: 0,
                           y: 0,
                           width: contentWidth,
                           height: newFrame.minY + textLayerYOffset + 5)
        var pointerFrame = CGRect(x: info.xPosition - 0.5,
                                  y: 0,
                                  width: 1,
                                  height: bounds.height)
        if minYPosition < contentFrame.maxY + textLayerYOffset {
            if info.xPosition < bounds.width / 2 {
                contentFrame.origin.x = info.xPosition + textLayerYOffset
            }
            else {
                contentFrame.origin.x = info.xPosition - textLayerYOffset - contentWidth
            }
        }
        else {
            contentFrame.origin.x = info.xPosition - contentWidth / 2
            pointerFrame.origin.y = contentFrame.maxY
            pointerFrame.size.height -= pointerFrame.origin.y
        }
        if contentFrame.maxX > bounds.maxX {
            contentFrame.origin.x = max(min(contentFrame.origin.x, bounds.maxX - contentFrame.width), info.xPosition + 0.5 - contentFrame.width)
        }
        else if contentFrame.minX < bounds.minX {
            contentFrame.origin.x = min(max(contentFrame.origin.x, bounds.minX), info.xPosition - 0.5)
        }
        
        if pointerFrame.minX > contentFrame.minX && pointerFrame.maxX < contentFrame.maxX {
            if contentFrame.minX + contentLayer.cornerRadius > pointerFrame.minX {
                pointerFrame.origin.y = sqrt(pow(contentLayer.cornerRadius, 2) - pow(pointerFrame.minX - contentFrame.minX - contentLayer.cornerRadius, 2)) + contentFrame.maxY - contentLayer.cornerRadius
            }
            else if contentFrame.maxX - contentLayer.cornerRadius < pointerFrame.maxX {
                pointerFrame.origin.y = sqrt(pow(contentLayer.cornerRadius, 2) - pow(pointerFrame.maxX - contentFrame.maxX + contentLayer.cornerRadius, 2)) + contentFrame.maxY - contentLayer.cornerRadius
            }
        }
        func positionState(contentFrame: CGRect, pointerFrame: CGRect) -> Int {
            if contentFrame.maxX < pointerFrame.minX {
                return 1
            }
            if contentFrame.minX > pointerFrame.maxX {
                return 2
            }
            return 0
        }
        let animatePosition = positionState(contentFrame: contentLayer.frame, pointerFrame: pointerLayer.frame) != positionState(contentFrame: contentFrame, pointerFrame: pointerFrame)

        pointerLayer.isHidden = !info.pointerVisible
        pointerLayer.backgroundColor = info.pointerVisible ? info.tooltipGridColor.cgColor : nil
        pointerLayer.frame = pointerFrame
        contentLayer.frame = contentFrame
        if animatePosition, let animation = contentLayer.animation(forKey: #keyPath(CALayer.position)) {
            contentLayer.add(animation, forKey: animationPrefix + #keyPath(CALayer.position))
        }
        let sameDate = oldInfo?.selectedDate == info.selectedDate
        if isHidden || sameDate {
            if sameDate {
                forEachLayerReqursive { $0.removeAllAnimations(without: animationPrefix) }
            }
            else {
                forEachLayerReqursive { $0.removeAllAnimations() }
            }
        }
        isHidden = !contentFrame.intersects(bounds)
    }
    
    private func createTextLayer(font: UIFont, alignmentMode: CATextLayerAlignmentMode = .left) -> CATextLayer {
        let layer = CATextLayer()
        layer.contentsScale = UIScreen.main.scale
        layer.alignmentMode = alignmentMode
        layer.setUIFont(font)
        layer.actions = disabledActions
        contentLayer.addSublayer(layer)
        return layer
    }
    
    private func createPointLayer() -> CALayer {
        let layer = CALayer()
        layer.contentsScale = UIScreen.main.scale
        addSublayer(layer)
        return layer
    }
}

extension TooltipLayer: CALayerDelegate {
    func draw(_ layer: CALayer, in ctx: CGContext) {
        guard let arrowFrame = arrowFrame else { return }
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.setFlatness(0.1)
        ctx.setLineJoin(.round)
        ctx.move(to: CGPoint(x: arrowFrame.minX, y: arrowFrame.minY))
        ctx.addLine(to: CGPoint(x: arrowFrame.maxX, y: arrowFrame.midY))
        ctx.addLine(to: CGPoint(x: arrowFrame.minX, y: arrowFrame.maxY))
        ctx.setStrokeColor(presentationTheme.tooltipArrowColor.cgColor)
        ctx.strokePath()
    }
}

private extension CALayer {
    func setPointer(_ center: CGPoint, side: CGFloat, lineWidth: CGFloat, lineColor: UIColor, backgroundColor: UIColor) {
        frame = CGRect(x: center.x - side / 2,
                       y: center.y - side / 2,
                       width: side,
                       height: side)
        cornerRadius = side / 2
        borderColor = lineColor.cgColor
        borderWidth = lineWidth
        self.backgroundColor = backgroundColor.cgColor
    }
}
