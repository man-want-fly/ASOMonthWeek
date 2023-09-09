//
//  DayColumnCell.swift
//  CalLib
//
//  Created by mwf on 2023/8/22.
//

import UIKit
import Reusable

struct DayColumnCellAccessoryType: OptionSet {

    let rawValue: Int

    static let none: DayColumnCellAccessoryType = []

    /// draw a dot under the day label (e.g. to indicate events on that day)
    static let dot = DayColumnCellAccessoryType(rawValue: 1 << 0)

    /// draw a mark around the day figure (e.g. to indicate today)
    static let mark = DayColumnCellAccessoryType(rawValue: 1 << 1)

    /// draw a border on the left side of the cell (day separator)
    static let border = DayColumnCellAccessoryType(rawValue: 1 << 2)

    /// draw a thick border (week separator)
    static let separator = DayColumnCellAccessoryType(rawValue: 1 << 3)
}

/// This collection view cell is used by the day planner view's subview dayColumnView.
/// It is responsible for drawing the day header and vertical separator between columns.
/// The day header displays the date, which can be marked, and eventually a dot below
/// that can indicate the presence of events. It can also show an activity indicator which
/// can be set visible while events are loading (see MGCDayPlannerView setActivityIndicatorVisible:forDate:)
class DayColumnCell: UICollectionViewCell, Reusable {

    private(set) lazy var dayLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }()
    
    private(set) lazy var dayHeader = DayColumnHeader()

    var accessoryTypes: DayColumnCellAccessoryType = .none {
        didSet {
            dayHeader.accessoryTypes = accessoryTypes
            setNeedsLayout()
        }
    }

    var markColor: UIColor = .black
    var separatorColor: UIColor = .separator
    var headerHeight: CGFloat = 56 {
        didSet {
            guard headerHeight != oldValue else { return }
            setNeedsLayout()
        }
    }

    private let leftBorder = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(dayHeader)
        contentView.layer.addSublayer(leftBorder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        accessoryTypes = .none
        markColor = .black
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if headerHeight != 0 {
            dayHeader.frame = .init(
                x: 0, y: 0, width: contentView.bounds.width, height: headerHeight)

            if accessoryTypes.contains(.mark) {
                dayLabel.layer.cornerRadius = 6
                dayLabel.layer.backgroundColor = markColor.cgColor
            } else {
                dayLabel.layer.cornerRadius = 0
                dayLabel.layer.backgroundColor = UIColor.clear.cgColor
            }
        }

        dayLabel.isHidden = headerHeight == 0

        // border
        var borderFrame = CGRect.zero
        let scale = UIScreen.current?.scale ?? 1
        
        if accessoryTypes.contains(.border) {
            borderFrame = CGRect(
                x: 0,
                y: headerHeight,
                width: 1.0 / scale,
                height: contentView.bounds.height - headerHeight
            )
        }
        if accessoryTypes.contains(.separator) {
            borderFrame = CGRect(
                x: 0,
                y: 0,
                width: 2.0 / scale,
                height: contentView.bounds.height
            )
        }

        leftBorder.frame = borderFrame
        leftBorder.borderColor = separatorColor.cgColor
        leftBorder.borderWidth = borderFrame.size.width / 2.0

        CATransaction.commit()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        
        if traitCollection != previousTraitCollection {
            headerHeight = traitCollection.isPortrait ? 56 : 32
        }
    }
}
