//
//  ValuesLayer.swift
//  TelegramContest
//
//  Created by Philip on 4/10/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class ValuesLayer: CALayer {
    enum Info {
        case area([(CGColor, [CGPoint])])
        case line([(CGColor, [CGPoint])])
        case bar([(CGColor, [CGRect])])
    }
    
    var lineWidth: CGFloat = 1
    var info: Info? {
        didSet {
            setNeedsDisplay()
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
    
    private func initialize() {
        contentsScale = UIScreen.main.scale
        drawsAsynchronously = true
    }
    
    override func draw(in ctx: CGContext) {
        ctx.setLineJoin(.round)
        ctx.setFlatness(0.1)
        ctx.setLineCap(.round)
        guard let info = info else {return}
        switch info {
        case .area(let info):
            ctx.setLineWidth(1 / UIScreen.main.scale)
            for i in 1..<info.count {
                ctx.setFillColor(info[i].0)
                ctx.setStrokeColor(info[i].0)
                ctx.addLines(between: info[i].1 + info[i - 1].1.reversed())
                ctx.drawPath(using: .fillStroke)
            }
        
        case .line(let info):
            ctx.setLineWidth(lineWidth)
            for (color, points) in info {
                ctx.setStrokeColor(color)
                ctx.addLines(between: points)
                ctx.strokePath()
            }
            
        case .bar(let info):
            for (color, rects) in info {
                ctx.setFillColor(color)
                ctx.addRects(rects)
                ctx.fillPath()
            }
        }
    }
}
