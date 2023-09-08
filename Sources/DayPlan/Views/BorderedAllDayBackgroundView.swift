//
//  BorderedAllDayBackgroundView.swift
//  AWSCalLib
//
//  Created by mwf on 2023/8/29.
//

import UIKit

class BorderedAllDayBackgroundView: UIView {

    private let topBorder = CALayer()

    private let bottomBorder = CALayer()
    
    var timeColumnWidth: CGFloat = 60

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true

        topBorder.backgroundColor = UIColor.separator.cgColor
        bottomBorder.backgroundColor = UIColor.separator.cgColor

        layer.addSublayer(topBorder)
        layer.addSublayer(bottomBorder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        let height: CGFloat = 1 / (UIScreen.current?.scale ?? 1)

        bottomBorder.frame = .init(
            x: bounds.origin.x,
            y: bounds.height - height,
            width: bounds.width + 2,
            height: height
        )
        
        topBorder.frame = .init(
            x: timeColumnWidth + height,
            y: 0,
            width: bounds.width - timeColumnWidth,
            height: bounds.height <= 1 ? .zero : height
        )
    }
}
