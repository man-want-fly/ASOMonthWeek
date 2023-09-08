//
//  MonthPlanViewDayCell.swift
//  CalLib
//
//  Created by mwf on 2023/8/13.
//

import UIKit
import Reusable

private let headerMargin: CGFloat = 1
private let dotSize: CGFloat = 8

class MonthPlanViewDayCell: UICollectionViewCell, Reusable {

    var headerHeight: CGFloat = 20 {
        didSet {
            setNeedsLayout()
        }
    }

    let dayLabel = UILabel()

    var showsDot = false {
        didSet {
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            dotLayer.isHidden = !showsDot
            CATransaction.commit()
        }
    }

    var dotColor: UIColor = .cyan {
        didSet {
            dotLayer.fillColor = dotColor.cgColor
        }
    }

    private lazy var dotLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path =
            UIBezierPath(ovalIn: .init(x: 0, y: 0, width: dotSize, height: dotSize)).cgPath
        shapeLayer.fillColor = UIColor.red.cgColor
        shapeLayer.isHidden = true
        return shapeLayer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemGroupedBackground
        dayLabel.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
        dayLabel.adjustsFontSizeToFitWidth = true
        contentView.addSubview(dayLabel)

        contentView.layer.addSublayer(dotLayer)

        let selectedView = UIView()
        selectedView.backgroundColor = UIColor.blue
        selectedBackgroundView = selectedView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        showsDot = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let headerFrame = CGRect(
            x: 0,
            y: 0,
            width: contentView.bounds.width,
            height: headerHeight
        )
        
        dayLabel.frame = headerFrame.insetBy(dx: headerMargin, dy: headerMargin)

        let contentFrame = CGRect(
            x: 0,
            y: headerHeight,
            width: contentView.bounds.width,
            height: contentView.bounds.height - headerHeight
        )
        .insetBy(dx: headerMargin, dy: headerMargin)

        let dotSize = min(min(contentFrame.height, contentFrame.width), dotSize)
        
        let dotFrame = CGRect(
            x: contentFrame.midX - dotSize * 0.5,
            y: contentFrame.midY - dotSize * 0.5,
            width: dotSize,
            height: dotSize
        )

        dotLayer.frame = dotFrame
    }
}
