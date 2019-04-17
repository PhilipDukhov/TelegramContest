import UIKit

extension ClosedRange where Bound : Numeric {
    var length: Bound {
        return upperBound - lowerBound
    }
}

extension CATextLayer {
    func setUIFont(_ uifont: UIFont?) {
        if let uifont = uifont {
            font = uifont.fontName as CFTypeRef
            fontSize = uifont.pointSize
        }
        else {
            font = nil
        }
    }
}


let disabledActions = [
    "position": NSNull(),
    "contents": NSNull(),
    "bounds": NSNull(),
    "foregroundColor": NSNull()
]

extension CALayer {
    func forEachLayerReqursive(_ body: (CALayer) -> Void) {
        var layers: [CALayer] = [self]
        while let layer = layers.popLast() {
            if let sublayers = layer.sublayers {
                layers += sublayers
            }
            body(layer)
        }
    }
    
    func removeAllAnimations(without prefix: String) {
        guard let animationKeys = animationKeys() else { return }
        for key in animationKeys {
            if !key.hasPrefix(prefix) {
                removeAnimation(forKey: key)
            }
        }
    }
}
