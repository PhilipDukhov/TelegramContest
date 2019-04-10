//
//  SliderView.swift
//  TelegramContest
//
//  Created by Philip on 3/17/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

private let kSliderWidth: CGFloat = 11

private func createSelectedMaskImage(withHeight height: CGFloat, color: UIColor, arrowColor: UIColor) -> UIImage? {
    let arrowSize = CGSize(width: 13/3, height: 34/3)
    let borderHeight: CGFloat = 1
    let contextSize = CGSize(width: kSliderWidth * 2 + 1, height: height)
    UIGraphicsBeginImageContextWithOptions(contextSize, false, UIScreen.main.scale)
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    context.setFillColor(color.cgColor)
    context.setStrokeColor(arrowColor.cgColor)
    
    UIBezierPath(roundedRect: CGRect(origin: .zero,
                                     size: contextSize),
                 cornerRadius: 1).fill()
    
    context.clear(CGRect(x: kSliderWidth,
                         y: borderHeight,
                         width: 1,
                         height: height - borderHeight * 2))
    
    let arrowPath = UIBezierPath()
    arrowPath.lineCapStyle = .round
    arrowPath.lineWidth = 1.5
    arrowPath.flatness = 0.1
    arrowPath.lineJoinStyle = .round
    
    arrowPath.move(to: CGPoint(x: (kSliderWidth + arrowSize.width) / 2,
                               y: (height - arrowSize.height) / 2))
    arrowPath.addLine(to: CGPoint(x: (kSliderWidth - arrowSize.width) / 2,
                                  y: height / 2))
    arrowPath.move(to: CGPoint(x: (kSliderWidth - arrowSize.width) / 2,
                               y: height / 2))
    arrowPath.addLine(to: CGPoint(x: (kSliderWidth + arrowSize.width) / 2,
                                  y: (height + arrowSize.height) / 2))
    
    arrowPath.stroke()
    
    arrowPath.apply(CGAffineTransform(scaleX: -1, y: 1).concatenating(CGAffineTransform(translationX: 2 * kSliderWidth + 1, y: 0)))
    arrowPath.stroke()
    
    let result = UIGraphicsGetImageFromCurrentImageContext()?
        .resizableImage(withCapInsets: UIEdgeInsets(top: borderHeight, left: kSliderWidth,
                                                    bottom: borderHeight, right: kSliderWidth))
    UIGraphicsEndImageContext()
    return result
}

class SliderView: UIControl {
    
    @IBOutlet weak var backgroundView: UIImageView!
    @IBOutlet weak var selectedView: UIImageView!
    @IBOutlet weak var selectedViewStartConstraint: NSLayoutConstraint!
    @IBOutlet weak var selectedViewEndConstraint: NSLayoutConstraint!
    @IBOutlet var coverViews: [UIView]!

    enum TrackingControl {
        case start
        case mid
        case end
        
        static var allControls: [TrackingControl] = [ .start, .mid, .end ]
    }
    
    private var _minValue: CGFloat = 0
    private var _maxValue: CGFloat = 1
    private var _minSelectedValue: CGFloat = 0
    private var _maxSelectedValue: CGFloat = 1
    private var _minSelectionRange: CGFloat = 0.1
    
    var minValue: CGFloat {
        set {
            if (_minValue != newValue) {
                _minValue = newValue
                self.minSelectedValue = _minSelectedValue
                setNeedsLayout()
            }
        }
        get {
            return _minValue
        }
    }
    
    var maxValue: CGFloat {
        set {
            if (_maxValue != newValue) {
                _maxValue = newValue
                _maxSelectedValue = newValue
                setNeedsLayout()
            }
        }
        get {
            return _maxValue
        }
    }
    
    var minSelectedValue: CGFloat {
        set {
            let newValue = max(min(newValue, maxSelectedValue - minSelectionRange), minValue)
            if (_minSelectedValue != newValue) {
                _minSelectedValue = newValue
                setNeedsLayout()
            }
        }
        get {
            return _minSelectedValue
        }
    }
    
    var maxSelectedValue: CGFloat {
        set {
            let newValue = min(max(newValue, minSelectedValue + minSelectionRange), maxValue)
            if (_maxSelectedValue != newValue) {
                _maxSelectedValue = newValue
                setNeedsLayout()
            }
        }
        get {
            return _maxSelectedValue
        }
    }
    
    var minSelectionRange: CGFloat {
        set {
            let newValue = max(newValue, 0)
            if (_minSelectionRange != newValue) {
                _minSelectionRange = newValue
                setNeedsLayout()
            }
        }
        get {
            return _minSelectionRange
        }
    }
    
    var minPosition: CGFloat {
        return 0
    }
    
    var maxPosition: CGFloat {
        return backgroundView.frame.width
    }
    
    
    var trackingControl = [UITouch:TrackingControl]()
    var initialPoint =  [UITouch:CGPoint]()
    var presentationTheme: PresentationTheme! {
        didSet {
            guard presentationTheme.isDark != oldValue?.isDark else { return }
            coverViews.forEach { $0.backgroundColor = presentationTheme.nonSelectedViewBackgroudColor }
            selectedView.image = nil
            setNeedsLayout()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        isMultipleTouchEnabled = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if selectedView.image?.size.height != selectedView.frame.height {
            selectedView.image = createSelectedMaskImage(withHeight: selectedView.frame.height,
                                                         color: presentationTheme.selectedViewBackgroundColor,
                                                         arrowColor: presentationTheme.selectedViewArrowColor)
        }
        setNeedsUpdateConstraints()
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        selectedViewStartConstraint.constant = position(for: minSelectedValue)
        selectedViewEndConstraint.constant = position(for: maxSelectedValue)
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        subview.isUserInteractionEnabled = false
    }
    
    // MARK: - UIControl
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if trackingControl.first(where: { $0.value == .mid }) != nil {
            return
        }
        for touch in touches where touch.phase == .began {
            if trackingControl.count >= 2 {
                break
            }
            var location = touch.location(in: self)
            guard trackingControl[touch] == nil, let control = nearestControl(to: location) else { continue }
            location.x -= self.position(for: control)
            initialPoint[touch] = location
            trackingControl[touch] = control
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard
                let trackingControl = trackingControl[touch],
                let initialPoint = initialPoint[touch]
                else { continue }
            let newValue = value(for: touch.location(in: self).x - initialPoint.x)
            switch trackingControl {
            case .start:
                minSelectedValue = newValue
                
            case .mid:
                let range = maxSelectedValue - minSelectedValue
                maxSelectedValue = maxValue
                minSelectedValue = min(newValue, maxValue - range)
                maxSelectedValue = minSelectedValue + range
                
            case .end:
                maxSelectedValue = newValue
            }
            sendActions(for: .valueChanged)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            trackingControl[touch] = nil
            initialPoint[touch] = nil
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            trackingControl[touch] = nil
            initialPoint[touch] = nil
        }
    }
    
    // MARK: - Helpers
    
    private func nearestControl(to point: CGPoint) -> TrackingControl? {
        var nearestControl: (TrackingControl?, CGFloat) = (nil, CGFloat.greatestFiniteMagnitude)
        for control in TrackingControl.allControls {
            if let distance = frame(for: control).distanceFromRectMid(to: point), distance < nearestControl.1 {
                nearestControl = (control, distance)
            }
        }
        return nearestControl.0
    }
    
    func position(for value: CGFloat) -> CGFloat {
        let result = (minPosition + (maxPosition - minPosition) * ((value - minValue) / (maxValue - minValue))).roundedScreenScaled
        return result.isFinite ? result : 0
    }
    
    func value(for position: CGFloat) -> CGFloat {
        let result = minValue + (position - minPosition) * (maxValue - minValue) / (maxPosition - minPosition)
        return result.isFinite ? result : 0
    }
    
    private func position(for trackingControl: TrackingControl) -> CGFloat {
        switch trackingControl {
        case .start, .mid:
            return selectedViewStartConstraint.constant
            
        case .end:
            return selectedViewEndConstraint.constant
        }
    }
    
    func frame(for control: TrackingControl) -> CGRect {
        switch control {
        case .start:
            return CGRect(x: selectedView.frame.minX,
                          y: selectedView.frame.minY,
                          width: kSliderWidth,
                          height: selectedView.frame.height)
            
        case .mid:
            return selectedView.frame
            
        case .end:
            return CGRect(x: selectedView.frame.maxX - kSliderWidth,
                          y: selectedView.frame.minY,
                          width: kSliderWidth,
                          height: selectedView.frame.height)
        }
    }

}
