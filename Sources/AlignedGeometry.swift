//
//  AlignedGeometry.swift
//  CalLib
//
//  Created by mwf on 2023/8/21.
//

import UIKit

extension CGRect {

    var aligned: CGRect {
        let scale = UIScreen.current?.scale ?? 1
        return CGRect(
            x: floor(origin.x * scale) / scale,
            y: floor(origin.y * scale) / scale,
            width: ceil(width * scale) / scale,
            height: ceil(height * scale) / scale
        )
    }
}

extension CGSize {
    
    var aligned: CGSize {
        let scale = UIScreen.current?.scale ?? 1
        return .init(
            width: ceil(width * scale) / scale,
            height: ceil(height * scale) / scale
        )
    }
}

extension CGPoint {
    
    var aligned: CGPoint {
        let scale = UIScreen.current?.scale ?? 1
        return .init(
            x: floor(x * scale) / scale,
            y: floor(y * scale) / scale
        )
    }
}

extension CGFloat {
    
    var aligned: CGFloat {
        let scale = UIScreen.current?.scale ?? 1
        return (self * scale).rounded(.toNearestOrAwayFromZero) / scale
    }
}

extension UIWindow {

    static var current: UIWindow? {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

extension UIScreen {

    static var current: UIScreen? {
        UIWindow.current?.screen
    }
}
