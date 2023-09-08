//
//  DayColumnHeader.swift
//  AWSCalLib
//
//  Created by mwf on 2023/8/28.
//

import UIKit

class DayColumnHeader: UIView {

    var date: Date? {
        didSet {
            guard let date else { return }
            weekLabel.text = dayFormatter.string(from: date)
            dayLabel.date = date
            weatherImageView.image = UIImage(systemName: "cloud.sun.rain.fill")
        }
    }

    var accessoryTypes: DayColumnCellAccessoryType = .none {
        didSet {
            dayLabel.accessoryTypes = accessoryTypes
        }
    }

    private lazy var dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = .current
        return formatter
    }()

    private let weekLabel = UILabel()

    private let dayLabel = DayView()

    private let weatherImageView = UIImageView()

    private let weekLabelHeight: CGFloat = 16
    private let dayLabelHeight: CGFloat = 24
    private let weatherButtonHeight: CGFloat = 24

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(weekLabel)
        addSubview(dayLabel)
        addSubview(weatherImageView)

        weekLabel.font = .systemFont(
            ofSize: UIFont.smallSystemFontSize,
            weight: .medium
        )
        weekLabel.textAlignment = .center
        weatherImageView.contentMode = .center
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if traitCollection.isPortrait {
            regularLayout()
        } else {
            compactLayout()
        }
    }

    private func regularLayout() {
        weekLabel.frame = .init(
            x: 0,
            y: 0,
            width: bounds.width,
            height: weekLabelHeight
        )
        dayLabel.frame = .init(
            x: 0,
            y: weekLabelHeight,
            width: bounds.width,
            height: dayLabelHeight
        )
        weatherImageView.frame = .init(
            x: 0,
            y: weekLabelHeight + dayLabelHeight,
            width: bounds.width,
            height: weatherButtonHeight
        )
    }

    private func compactLayout() {
        weekLabel.frame = .init(
            x: 0,
            y: 0,
            width: bounds.midX,
            height: weekLabelHeight
        )
        dayLabel.frame = .init(
            x: 0,
            y: weekLabelHeight,
            width: bounds.midX,
            height: dayLabelHeight
        )
        weatherImageView.frame = .init(
            x: bounds.midX,
            y: weekLabelHeight,
            width: bounds.midX,
            height: dayLabelHeight
        )
    }
}

private class DayView: UIView {

    var date: Date? {
        didSet {
            guard let date else { return }
            dayLabel.text = dayFormatter.string(from: date)
        }
    }

    var accessoryTypes: DayColumnCellAccessoryType = .none {
        didSet {
            setNeedsLayout()
        }
    }

    private let dayLabel = UILabel()

    private let indicatorLayer = CAShapeLayer()

    var markColor: UIColor = .cyan

    private lazy var dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        dayLabel.font = .boldSystemFont(ofSize: UIFont.systemFontSize)
        dayLabel.textAlignment = .center

        indicatorLayer.fillColor = markColor.cgColor
        layer.addSublayer(indicatorLayer)
        addSubview(dayLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        dayLabel.frame = bounds

        let hasMark = accessoryTypes.contains(.mark)

        if hasMark {
            let indicatorWidth = bounds.height

            indicatorLayer.path =
                UIBezierPath(
                    ovalIn: .init(
                        x: bounds.midX - indicatorWidth / 2,
                        y: 0,
                        width: indicatorWidth,
                        height: indicatorWidth
                    )
                )
                .cgPath

            indicatorLayer.fillColor = UIColor.tintColor.cgColor
        }

        indicatorLayer.isHidden = !hasMark
        dayLabel.textColor = hasMark ? .white : .label
    }
}
