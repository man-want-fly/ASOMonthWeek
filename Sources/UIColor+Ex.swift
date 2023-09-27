//
//  UIColorExtension.swift
//
//
//  Created by mwf on 2023/9/11.
//

import UIKit

extension UIColor {

    private func hsb(saturationRatio: CGFloat = 1, brightnessRatio: CGFloat = 1) -> UIColor {
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
            saturation: saturation * saturationRatio,
            brightness: brightness * brightnessRatio,
            alpha: alpha
        )
    }
    
    var eventBackgroundColor: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
            ? self.hsb(brightnessRatio: 0.3)
            : self.hsb(saturationRatio: 0.2)
        }
    }
    
    var eventTitleColor: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark
            ? self
            : self.hsb(brightnessRatio: 0.5)
        }
    }
}
