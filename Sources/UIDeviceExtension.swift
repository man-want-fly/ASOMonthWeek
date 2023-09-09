//
//  UIDeviceExtension.swift
//  
//
//  Created by mwf on 2023/9/9.
//

import UIKit

public extension UIDevice {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}

public extension UITraitEnvironment {

    var isPortrait: Bool {
        UITraitCollection.current.isPortrait
    }
}

public extension UITraitCollection {
    
    var isPortrait: Bool {
        if UIDevice.isPhone {
            return horizontalSizeClass == .compact
                && verticalSizeClass == .regular
        }
        if UIDevice.isPad {
            return horizontalSizeClass == .regular
                && verticalSizeClass == .regular
        }
        return UIDevice.current.orientation == .portrait
    }
}
