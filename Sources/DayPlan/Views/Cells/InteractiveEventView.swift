//
//  InteractiveEventView.swift
//  CalLib
//
//  Created by mwf on 2023/8/22.
//

import UIKit

class InteractiveEventView: UIView {

    var eventView: EventView? {
        didSet {
            guard let eventView, eventView != oldValue else { return }
            oldValue?.removeFromSuperview()
            addSubview(eventView)
            eventView.selected = true
            setNeedsLayout()
        }
    }
    
    var forbiddenSignVisible: Bool = false
    
    private lazy var forbiddenSignLayer: CATextLayer = {
        let layer = CATextLayer()
        layer.string = "\u{26D4}"
        layer.fontSize = 16
        layer.contentsScale = UIScreen.current?.scale ?? 1
        layer.alignmentMode = .center
        layer.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        layer.zPosition = 10
        layer.position = .zero
        return layer
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.addSublayer(forbiddenSignLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        eventView?.frame = bounds
    }

}
