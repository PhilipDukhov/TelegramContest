import UIKit

func +(color1: UIColor, color2: UIColor) -> UIColor {
    var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    
    color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    
    return UIColor(red: r2 * a2 + (1 - a2) * r1,
                   green: g2 * a2 + (1 - a2) * g1,
                   blue: b2 * a2 + (1 - a2) * b1,
                   alpha: 1)
}

func +(color1: CGColor, color2: CGColor) -> CGColor {
    var color1 = color1
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    if color1.colorSpace?.model != .rgb {
        color1 = color1.converted(to: space, intent: .saturation, options: nil) ?? color1
    }
    var color2 = color2
    if color2.colorSpace?.model != .rgb {
        color2 = color2.converted(to: space, intent: .saturation, options: nil) ?? color2
    }
    
    guard color1.colorSpace?.model == color2.colorSpace?.model,
        color1.numberOfComponents == color2.numberOfComponents,
        let components1 = color1.components,
        let components2 = color2.components
        else { fatalError("error") }
    var resultComponents = [CGFloat]()
    let alpha2 = components2.last!
    for i in 0..<color1.numberOfComponents - 1 {
        resultComponents.append(components1[i] * (1 - alpha2) + components2[i] * alpha2)
    }
    resultComponents.append(1)
    return CGColor(colorSpace: space, components: resultComponents)!
}

extension UIColor {
    convenience init(hex string: String) {
        let hex = string.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt32()
        Scanner(string: hex).scanHexInt32(&int)
        let a, r, g, b: UInt32
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
