//
//  MonthPlanWeekView.swift
//  CalLib
//
//  Created by mwf on 2023/8/14.
//

import UIKit

class MonthPlanWeekView: UICollectionReusableView {
    
    private var _eventsView: EventsRowView?
    
    var eventsView: EventsRowView? {
        get {
            return _eventsView
        }
        set(newEventsView) {
            var z: Int = NSNotFound
            if let currentEventsView = _eventsView {
                z = subviews.firstIndex(of: currentEventsView) ?? NSNotFound
            }

            if z == NSNotFound {
                //eventsView.frame = self.bounds;
                addSubview(newEventsView!)
            } else {
                _eventsView?.removeFromSuperview()
                insertSubview(newEventsView!, at: z)
            }
            _eventsView = newEventsView
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        eventsView?.frame = bounds
    }
}
