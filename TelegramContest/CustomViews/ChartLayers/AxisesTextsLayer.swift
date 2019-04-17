//
//  AxisesTextsLayer.swift
//  TelegramContest
//
//  Created by Philip on 4/10/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class AxisesTextsLayer: CALayer {
    struct Info {
        struct GridInfo {
            let gridColor: UIColor
            let gridFrames: [CGRect]
        }
        
        let textColor: UIColor
        let stringsAndFrames: [String: CGRect]
        let gridInfo: GridInfo?
    }
    
    private var visibleTextLayers = [String:CATextLayer]()
    private var cachedTextLayers = [CATextLayer]()
    
    private var visibleGridLayers = [CALayer]()
    private var cachedGridLayers = [CALayer]()
    
    var info: Info? {
        didSet {
            isHidden = info == nil
            setNeedsLayout()
        }
    }
    
    var font: UIFont!
    
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
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        var newDateLayers = [String:CATextLayer]()
        var newGreedLayers = [CALayer]()
        defer {
            (visibleGridLayers + Array(visibleTextLayers.values)).forEach { $0.removeFromSuperlayer() }
            cachedTextLayers += visibleTextLayers.values
            cachedGridLayers += visibleGridLayers
            visibleTextLayers = newDateLayers
            visibleGridLayers = newGreedLayers
        }
        guard let info = info else { return }
        for (string, frame) in info.stringsAndFrames where frame.minY >= 0 && frame.maxY <= bounds.height {
            let dateLayer = visibleTextLayers.removeValue(forKey: string) ?? deqeueTextLayer()
            dateLayer.foregroundColor = info.textColor.cgColor
            dateLayer.string = string
            dateLayer.frame = frame
            newDateLayers[string] = dateLayer
        }
        
        guard let gridInfo = info.gridInfo else { return }
        newGreedLayers = gridInfo.gridFrames.compactMap { frame -> CALayer? in
            let layer = visibleGridLayers.popLast() ?? deqeueGreedLayer()
            layer.backgroundColor = gridInfo.gridColor.cgColor
            layer.frame = frame
            return layer
        }
    }
    
    private func deqeueTextLayer() -> CATextLayer {
        let result: CATextLayer
        if cachedTextLayers.count > 0 {
            result = cachedTextLayers.popLast()!
        }
        else {
            result = CATextLayer()
            result.contentsScale = UIScreen.main.scale
            result.setUIFont(font)
            result.actions = disabledActions
        }
        addSublayer(result)
        return result
    }
    
    private func deqeueGreedLayer() -> CALayer {
        let result: CALayer
        if cachedGridLayers.count > 0 {
            result = cachedGridLayers.popLast()!
        }
        else {
            result = CALayer()
            result.actions = disabledActions
        }
        addSublayer(result)
        return result
    }
}
