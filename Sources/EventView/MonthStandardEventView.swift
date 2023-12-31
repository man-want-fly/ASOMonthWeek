//
//  MonthStandardEventView.swift
//
//
//  Created by mwf on 2023/9/9.
//

import UIKit

class MonthStandardEventView: EventView {

    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }

    var color: UIColor = .white {
        didSet {
            resetColors()
        }
    }

    private lazy var leftBorderView = UIView()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = UIFont.systemFont(ofSize: 11)
        label.lineBreakMode = .byCharWrapping
        return label
    }()

    required init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(leftBorderView)
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        leftBorderView.frame = .init(
            x: 0,
            y: 0.5,
            width: 2,
            height: bounds.height - 1
        )

        let h = titleLabel.intrinsicContentSize.height

        titleLabel.frame = .init(
            x: 4,
            y: (bounds.height - h) * 0.5,
            width: bounds.width - 8,
            height: h
        )
    }

    override var selected: Bool {
        didSet {
            resetColors()
        }
    }

    private func resetColors() {
        leftBorderView.backgroundColor = color
        backgroundColor = selected ? color : color.eventBackgroundColor
        titleLabel.textColor = selected ? .white : color.eventTitleColor
    }
}
