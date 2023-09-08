//
//  MonthPlanBackgroundView.swift
//  CalLib
//
//  Created by mwf on 2023/8/14.
//

import UIKit

class MonthPlanBackgroundView: UICollectionReusableView {

    var numberOfColumns: Int = 7
    var numberOfRows: Int = 6
    var firstColumn: Int = 0
    var lastColumn: Int = 6

    var drawVerticalLines: Bool = true
    var drawHorizontalLines: Bool = true

    var drawBottomDayLabelLines: Bool = true
    var dayCellHeaderHeight: CGFloat = 0

    var gridColor: UIColor = .separator

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        isUserInteractionEnabled = false
        lastColumn = 6
        drawHorizontalLines = true
        drawVerticalLines = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }

        let colWidth: CGFloat =
            numberOfColumns > 0
            ? (bounds.width / CGFloat(numberOfColumns))
            : bounds.width

        let rowHeight: CGFloat =
            numberOfRows > 0
            ? (bounds.height / CGFloat(numberOfRows))
            : bounds.height

        c.setStrokeColor(gridColor.cgColor)
        c.setLineWidth(0.5)

        c.beginPath()

        var x1: CGFloat = 0.0
        var y1: CGFloat = 0.0
        var x2: CGFloat = 0.0
        var y2: CGFloat = 0.0

        if drawHorizontalLines {
            for i in 0...numberOfRows {
                y1 = rowHeight * CGFloat(i)
                y2 = y1
                x1 = i == 0 ? CGFloat(firstColumn) * colWidth : 0
                x2 = i == numberOfRows ? CGFloat(lastColumn) * colWidth : rect.maxX

                c.move(to: CGPoint(x: x1, y: y1))
                c.addLine(to: CGPoint(x: x2, y: y2))
            }
        }

        if dayCellHeaderHeight > 0 && drawBottomDayLabelLines {
            for i in 0..<numberOfRows {
                y1 = rowHeight * CGFloat(i) + dayCellHeaderHeight
                y2 = y1
                x1 = i == 0 ? CGFloat(firstColumn) * colWidth : 0
                x2 = i == (numberOfRows - 1) ? CGFloat(lastColumn) * colWidth : rect.maxX

                c.move(to: CGPoint(x: x1, y: y1))
                c.addLine(to: CGPoint(x: x2, y: y2))
            }
        }

        if drawVerticalLines {
            for j in 0...numberOfColumns {
                x1 = colWidth * CGFloat(j)
                x2 = x1
                y1 = j < firstColumn ? rowHeight : 0
                y2 =
                    j <= lastColumn
                    ? CGFloat(numberOfRows) * rowHeight
                    : CGFloat(numberOfRows - 1) * rowHeight

                c.move(to: CGPoint(x: x1, y: y1))
                c.addLine(to: CGPoint(x: x2, y: y2))
            }
        }

        c.strokePath()
    }
}
