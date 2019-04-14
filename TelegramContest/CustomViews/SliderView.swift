//
//  SliderView.swift
//  TelegramContest
//
//  Created by Philip on 3/17/19.
//  Copyright © 2019 Philip Dukhov. All rights reserved.
//

import UIKit

class SliderView: UIControl {
    private let kSliderWidth: CGFloat = 11
    
    @IBOutlet weak var backgroundView: UIView!
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
    
    func setSelectedValues(minValue: CGFloat, maxValue: CGFloat) {
        _minSelectedValue = max(self.minValue, minValue)
        _maxSelectedValue = min(self.maxValue, maxValue)
        setNeedsLayout()
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
    var offset: CGFloat { return presentationTheme.isDark ? 0 : 1 }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        isMultipleTouchEnabled = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if selectedView.image?.size.height != selectedView.frame.height {
            selectedView.image = presentationTheme.selectedMaskImage(withHeight: selectedView.frame.height,
                                                                     sliderWidth: kSliderWidth)
        }
        setNeedsUpdateConstraints()
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        selectedViewStartConstraint.constant = position(for: minSelectedValue) - offset
        selectedViewEndConstraint.constant = position(for: maxSelectedValue) + offset
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
            return selectedViewStartConstraint.constant + offset
            
        case .end:
            return selectedViewEndConstraint.constant - offset
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
