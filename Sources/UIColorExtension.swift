//
//  UIColorExtension.swift
//
//
//  Created by mwf on 2023/9/11.
//

import UIKit

extension UIColor {

    func hsb(brightnessDecreased: CGFloat = 0.3) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        ) else { return self }
        
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: max(brightness - brightnessDecreased, 0),
            alpha: alpha
        )
    }
}
