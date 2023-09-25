//
//  MonthPlanViewDayCell.swift
//  CalLib
//
//  Created by mwf on 2023/8/13.
//

import UIKit
import Reusable

class MonthPlanViewDayCell: UICollectionViewCell, Reusable {

    var headerHeight: CGFloat = 24 {
        didSet {
            setNeedsLayout()
        }
    }

    let dayLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        dayLabel.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
        dayLabel.adjustsFontSizeToFitWidth = true
        contentView.addSubview(dayLabel)

        let selectedView = UIView()
        selectedView.backgroundColor = .tertiarySystemGroupedBackground
        selectedBackgroundView = selectedView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let headerFrame = CGRect(
            x: 0,
            y: 0,
            width: contentView.bounds.width,
            height: headerHeight
        )
        
        dayLabel.frame = headerFrame.insetBy(dx: 1, dy: 0)
    }
}
