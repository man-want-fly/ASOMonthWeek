//
//  DayColumnViewFlowLayout.swift
//  CalLib
//
//  Created by mwf on 2023/8/21.
//

import UIKit

class DayColumnViewFlowLayout: UICollectionViewFlowLayout {

    override func invalidationContext(
        forBoundsChange newBounds: CGRect
    ) -> UICollectionViewLayoutInvalidationContext {
        
        let context = super.invalidationContext(forBoundsChange: newBounds)
        
        guard let context = context as? UICollectionViewFlowLayoutInvalidationContext
        else { return context }
        
        context.invalidateFlowLayoutDelegateMetrics = newBounds.size != collectionView?.bounds.size
        
        return context
    }
}
