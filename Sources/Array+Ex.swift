//
//  File.swift
//  
//
//  Created by mwf on 2023/9/25.
//

import Foundation

extension Array {

    var middle: Element? {
        guard count != 0 else { return nil }

        let middleIndex = (count > 1 ? count - 1 : count) / 2
        return self[middleIndex]
    }
}
