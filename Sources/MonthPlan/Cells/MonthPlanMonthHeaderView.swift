//
//  MonthPlanHeaderView.swift
//  CalLib
//
//  Created by mwf on 2023/8/14.
//

import UIKit

class MonthPlanMonthHeaderView: UICollectionReusableView {

    private var labels: [UILabel] = []

    var weekStrings: [String] = [] {
        didSet {
            zip(labels, weekStrings)
                .forEach { label, text in
                    label.text = text
                }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        labels = (0..<7)
            .map { _ in
                let label = UILabel()
                label.textAlignment = .center
                label.textColor = .label
                label.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
                return label
            }

        backgroundColor = .clear
        autoresizesSubviews = true

        labels.forEach(addSubview)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let w = bounds.width / CGFloat(labels.count)
        for (index, label) in labels.enumerated() {
            label.frame = .init(
                x: CGFloat(index) * w,
                y: 0,
                width: w,
                height: bounds.height
            )
        }
    }
}
