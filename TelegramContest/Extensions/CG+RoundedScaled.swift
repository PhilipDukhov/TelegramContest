import UIKit


let kMinControlSide: CGFloat = 45

extension CGFloat {
    public var roundedScreenScaled: CGFloat {
        return roundedScreenScaled(.toNearestOrAwayFromZero)
        
    }
    public func roundedScreenScaled(_ rule: FloatingPointRoundingRule) -> CGFloat {
        return (self * UIScreen.main.nativeScale).rounded(rule) / UIScreen.main.nativeScale
    }
}

extension CGPoint {
    var roundedScreenScaled: CGPoint {
        var point = self
        point.x = point.x.roundedScreenScaled
        point.y = point.y.roundedScreenScaled
        return point
        
    }
}

extension CGSize {
    var roundedScreenScaled: CGSize {
        var size = self
        size.width = size.width.roundedScreenScaled
        size.height = size.height.roundedScreenScaled
        return size        
    }
}

extension CGRect {
    var roundedScreenScaled: CGRect {
        return CGRect(origin: origin.roundedScreenScaled, size: size.roundedScreenScaled)
    }
}


extension CGRect {
    var controlOprimized: CGRect {
        return insetBy(dx: min(0, width - kMinControlSide)/2,
                       dy: min(0, height - kMinControlSide)/2)
    }
    
    func distanceFromRectMid(to point: CGPoint) -> CGFloat? {
        if controlOprimized.contains(point) {
            return hypot(point.x - midX,
                         point.y - midY)
        }
        return nil
    }
}

extension CGFloat
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
