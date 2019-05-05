//
//  ValuesLayer.swift
//  TelegramContest
//
//  Created by Philip on 4/10/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

fileprivate extension CGPathDrawingMode {
    var isStroke: Bool {
        switch self {
        case .stroke, .eoFillStroke, .fillStroke:
            return true
            
        default:
            return false
        }
    }
    var isFill: Bool {
        switch self {
        case .fill, .eoFill, .eoFillStroke, .fillStroke:
            return true
            
        default:
            return false
        }
    }
}

class ValuesLayer: CALayer {
    struct Info {
        struct PathInfo {
            let path: CGPath
            let color: CGColor
        }
        struct TextInfo {
            let string: String
            var frame: CGRect
            var font: UIFont
        }
        let drawingMode: CGPathDrawingMode
        let lineWidth: CGFloat?
        let pathInfos: [PathInfo]
        let textInfos: [TextInfo]?
    }
    
    var info: Info? {
        didSet {
            setNeedsDisplay()
            update()
        }
    }
    
    private var shapeLayers = [CGColor:CAShapeLayer]()
    
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
        contentsScale = UIScreen.main.scale
        drawsAsynchronously = true
    }
    
    func update() {
        guard let info = info else {
            return
        }
        var newShapeLayers = [CGColor:CAShapeLayer]()
        for pathInfo in info.pathInfos {
            let layer = shapeLayers.removeValue(forKey: pathInfo.color) ?? newLayer()
            layer.fillColor = info.drawingMode.isFill ? pathInfo.color : nil
            layer.strokeColor = info.drawingMode.isStroke ? pathInfo.color : nil
            layer.lineWidth = info.lineWidth ?? 0
            layer.path = pathInfo.path
            newShapeLayers[pathInfo.color] = layer
        }
        shapeLayers.forEach { $0.1.removeFromSuperlayer() }
        shapeLayers = newShapeLayers
    }
    
    private func newLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.lineJoin = .round
        layer.lineCap = .round
        layer.contentsScale = UIScreen.main.scale
        layer.frame = bounds
        addSublayer(layer)
        return layer
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        shapeLayers.forEach { $0.1.frame = bounds }
    }
    
    override func draw(in ctx: CGContext) {
        guard let info = info else {return}
        if let textInfos = info.textInfos {
            UIGraphicsPushContext(ctx)
            for textInfo in textInfos {
                NSString(string: textInfo.string).draw(in: textInfo.frame,
                                                                withAttributes: [.font: textInfo.font,
                                                                                 .foregroundColor: UIColor.white])
            }
            UIGraphicsPopContext()
        }
    }
}
