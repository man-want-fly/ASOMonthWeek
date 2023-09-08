//
//  EventCell.swift
//  CalLib
//
//  Created by mwf on 2023/8/22.
//

import UIKit
import Reusable

/// This collection view cell is used by the day planner view's subviews timedEventsView
/// and allDayEventsView.
/// It is the parent view for event content views, which are subclasses of MGCEventView.
class EventCell: UICollectionViewCell, Reusable {

    var eventView: EventView? {
        didSet {
            if let eventView, eventView != oldValue {
                oldValue?.removeFromSuperview()
                
                contentView.addSubview(eventView)
                setNeedsLayout()
                
                eventView.visibleHeight = visibleHeight
            }
        }
    }
    
    var visibleHeight: CGFloat = .greatestFiniteMagnitude
    
    override var isSelected: Bool {
        didSet {
            super.isSelected = isSelected
            eventView?.selected = isSelected
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        eventView?.frame = contentView.bounds
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        guard let layoutAttributes = layoutAttributes as? EventCellLayoutAttributes
        else { return }
        visibleHeight = layoutAttributes.visibleHeight
    }
}
