//
//  EventCell.swift
//  CalLib
//
//  Created by mwf on 2023/8/22.
//

import UIKit
import Reusable

open class EventCell: UICollectionViewCell, Reusable {

    open var eventView: EventView? {
        didSet {
            if let eventView, eventView != oldValue {
                oldValue?.removeFromSuperview()
                
                contentView.addSubview(eventView)
                setNeedsLayout()
                
                eventView.visibleHeight = visibleHeight
            }
        }
    }
    
    open var visibleHeight: CGFloat = .greatestFiniteMagnitude
    
    open override var isSelected: Bool {
        didSet {
            super.isSelected = isSelected
            eventView?.selected = isSelected
        }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        eventView?.frame = contentView.bounds
    }
    
    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        guard let layoutAttributes = layoutAttributes as? EventCellLayoutAttributes
        else { return }
        visibleHeight = layoutAttributes.visibleHeight
    }
}
