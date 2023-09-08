//
//  EventCellLayoutAttributes.swift
//  CalLib
//
//  Created by mwf on 2023/8/21.
//

import UIKit

class EventCellLayoutAttributes: UICollectionViewLayoutAttributes {

    var visibleHeight: CGFloat = 0
    var numberOfOtherCoveredAttributes: Int = 0

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? EventCellLayoutAttributes else {
            return false
        }

        if !super.isEqual(object) {
            return false
        }

        return object.visibleHeight == visibleHeight
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        let attr = super.copy(with: zone)
        guard let attr = attr as? EventCellLayoutAttributes else { return attr }
        attr.visibleHeight = visibleHeight
        return attr
    }
}
