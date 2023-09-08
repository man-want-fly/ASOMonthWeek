//
//  ReusableConstants.swift
//  AWSCalLib
//
//  Created by mwf on 2023/8/29.
//

import Foundation

enum ReusableConstants {}

extension ReusableConstants {
    
    enum Kind {
        static let moreEvents = "MoreEventsViewKind"
        static let dimmingView = "DimmingViewKind"
        
        static let monthBackground = "MonthBackgroundViewKind"
        static let monthRow = "MonthRowViewKind"
        static let monthHeader = "MonthHeaderViewKind"
        static let monthWeekHeader = "MonthWeekHeaderViewKind"
    }
    
    enum Identifier {
        static let dimmingView = "DimmingViewReuseIdentifier"
        static let timeRowCell = "TimeRowCellReuseIdentifier"
        static let moreEventsView = "MoreEventsViewReuseIdentifier"
        static let eventCell = "EventCellReuseIdentifier"
        
        
        static let eventsRowView = "EventsRowViewIdentifier"
        static let dayCell = "DayCellIdentifier"
        static let monthRowView = "MonthRowViewIdentifier"
        static let monthHeaderView = "MonthHeaderViewIdentifier"
        static let monthWeekHeaderView = "MonthWeekHeaderViewIdentifier"
        static let monthBackgroundView = "MonthBackgroundViewIdentifier"
    }
}
