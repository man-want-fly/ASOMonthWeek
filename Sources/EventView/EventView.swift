//
//  EventView.swift
//  CalLib
//
//  Created by mwf on 2023/8/12.
//

import UIKit

public enum EventType: Int {
    case allDay = 0, timed
}

public class EventView: UIView, ReusableObject {
    
    public var reuseIdentifier: String = "EventView"
    
    var selected: Bool = false
    
    var visibleHeight: CGFloat = .greatestFiniteMagnitude
    
    public func prepareForReuse() {
        selected = false
    }
    
    func didTransition(to eventType: EventType) {
        
    }
    
    required override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
        clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
