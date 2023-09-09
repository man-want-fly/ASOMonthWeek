//
//  UIDeviceExtension.swift
//
//
//  Created by mwf on 2023/9/9.
//

import UIKit

extension UIDevice {
    public static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    public static var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}

extension UITraitEnvironment {

    public var isPortrait: Bool {
        UITraitCollection.current.isPortrait
    }
}

extension UITraitCollection {

    public var isPortrait: Bool {
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

    public var orientation: UIInterfaceOrientation {
        UIApplication.shared
            .connectedScenes
            .first(where: { $0 is UIWindowScene })
            .flatMap { $0 as? UIWindowScene }?
            .interfaceOrientation ?? .unknown
    }
}
