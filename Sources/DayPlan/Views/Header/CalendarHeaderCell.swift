//
//  CalendarHeaderCell.swift
//  CalLib
//
//  Created by mwf on 2023/8/23.
//

import UIKit
import Reusable

class CalendarHeaderCell: UICollectionViewCell, Reusable {

    lazy var dayNumberLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        return label
    }()

    lazy var dayNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        return label
    }()

    var date: Date? {
        didSet {
            guard let date else { return }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "E"
            dayNameLabel.text = dateFormatter.string(from: date)
            
            dateFormatter.dateFormat = "d"
            dayNumberLabel.text = dateFormatter.string(from: date)
            
            isToday = Calendar.current.isDate(Date(), inSameDayAs: date)
            isWeekend = Calendar.current.isDateInWeekend(date)
        }
    }

    private var isToday: Bool = false
    private var isWeekend: Bool = false

    private var selectedDayBackgroundColor: UIColor = .darkGray
    private var selectedDayTextColor: UIColor = .label
    private var todayColor: UIColor = .systemRed
    private var weekendColor: UIColor = .systemGray

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(dayNameLabel)
        contentView.addSubview(dayNumberLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isSelected: Bool {
        didSet {
            super.isSelected = isSelected

            setNeedsLayout()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        dayNameLabel.textColor = .label
        dayNumberLabel.textColor = .label
        isToday = false
        isWeekend = false
        selectedDayBackgroundColor = .darkGray
        selectedDayTextColor = .white
        todayColor = .red
        weekendColor = .gray
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        dayNameLabel.frame = .init(
            x: 4,
            y: 0,
            width: bounds.width - 8,
            height: 21
        )
        dayNumberLabel.frame = .init(
            x: 0,
            y: 21,
            width: bounds.width,
            height: bounds.height - 21
        )

        if isSelected {
            dayNumberLabel.backgroundColor = selectedDayBackgroundColor
            dayNumberLabel.layer.masksToBounds = true
            dayNumberLabel.layer.cornerRadius = 15.0
            dayNumberLabel.textColor = selectedDayTextColor
        } else {
            dayNumberLabel.backgroundColor = .clear
            dayNumberLabel.textColor = selectedDayBackgroundColor
        }

        if isToday {
            dayNumberLabel.textColor = todayColor
            dayNameLabel.textColor = todayColor
        }
        if isWeekend, !isToday {
            dayNumberLabel.textColor = weekendColor
            dayNameLabel.textColor = weekendColor
        }
    }
}
