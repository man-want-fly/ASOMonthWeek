//
//  MonthPlanViewLayout.swift
//  CalLib
//
//  Created by mwf on 2023/8/12.
//

import UIKit

public protocol MonthPlannerViewLayoutDelegate: UICollectionViewDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MonthPlanViewLayout,
        columnForDayAt indexPath: IndexPath
    ) -> Int
}

public class MonthPlanViewLayout: UICollectionViewFlowLayout {

    typealias LayoutItems = [IndexPath: UICollectionViewLayoutAttributes]

    enum ElementKind: String {
        case day
        case event
        case month
    }

    weak var delegate: MonthPlannerViewLayoutDelegate?

    var rowHeight: CGFloat
    var dayHeaderHeight: CGFloat

    private var layoutInfo: [ElementKind: [IndexPath: UICollectionViewLayoutAttributes]] = [:]

    private var contentWidth: CGFloat = 0
    private let monthHeaderHeight: CGFloat = 56

    private var weekHeight: CGFloat {
        rowHeight - dayHeaderHeight
    }

    override init() {
        rowHeight = 0
        dayHeaderHeight = 28

        super.init()
        
        minimumLineSpacing = 0
        minimumInteritemSpacing = 0
        scrollDirection = .horizontal
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func prepare() {
        guard let collectionView else { return }

        var layoutInfo = [ElementKind: LayoutItems]()
        var dayCellsInfo = LayoutItems()
        var monthsInfo = LayoutItems()
        var rowsInfo = LayoutItems()

        collectionView.isPagingEnabled = true

        let numberOfMonths = collectionView.numberOfSections

        var pageX: CGFloat = 0

        let pageWidth = collectionView.bounds.width

        let pageHeight = collectionView.bounds.height - monthHeaderHeight

        contentWidth = pageWidth * CGFloat(numberOfMonths)

        for month in 0..<numberOfMonths {

            var col = delegate!
                .collectionView(
                    collectionView,
                    layout: self,
                    columnForDayAt: IndexPath(item: 0, section: month)
                )

            let daysInMonth = collectionView.numberOfItems(inSection: month)
            let numOfRows = Int((Double(col + daysInMonth) / 7.0).rounded(.up))

            var day = 0

            rowHeight = pageHeight / CGFloat(numOfRows)

            pageX = pageWidth * CGFloat(month)

            let monthRect = CGRect(
                x: pageX,
                y: monthHeaderHeight,
                width: pageWidth,
                height: pageHeight
            )

            // header
            let headerIndexPath = IndexPath(item: 1, section: month)
            monthsInfo[headerIndexPath] = makeHeaderAttributes(
                for: headerIndexPath,
                pageX,
                pageWidth
            )

            for row in 0..<numOfRows {
                let colRange = NSMakeRange(col, min(7 - col, daysInMonth - day))

                // event
                let eventIdx = IndexPath(item: day, section: month)
                let eventAttributes = UICollectionViewLayoutAttributes(
                    forSupplementaryViewOfKind: ReusableConstants.Kind.monthRow,
                    with: eventIdx
                )
                eventAttributes.frame = CGRect(
                    x: widthForColumnRange(NSMakeRange(0, col)) + pageWidth * CGFloat(month),
                    y: monthHeaderHeight + CGFloat(row) * weekHeight + CGFloat(row) * dayHeaderHeight
                        + dayHeaderHeight,
                    width: pageWidth,
                    height: weekHeight
                )
                eventAttributes.zIndex = 2
                rowsInfo[eventIdx] = eventAttributes

                // day
                for col in col..<NSMaxRange(colRange) {
                    let path = IndexPath(item: day, section: month)
                    let attributes = UICollectionViewLayoutAttributes(forCellWith: path)
                    attributes.frame = CGRect(
                        x: widthForColumnRange(NSMakeRange(0, col)) + pageWidth
                            * CGFloat(month),
                        y: monthHeaderHeight + rowHeight * CGFloat(row),
                        width: widthForColumnRange(NSMakeRange(col, 1)),
                        height: rowHeight
                    )
                    dayCellsInfo[path] = attributes
                    day += 1
                }

                col = 0
            }

            // background grid
            let monthIndexPath = IndexPath(item: 0, section: month)
            monthsInfo[monthIndexPath] = makeMonthAttributes(
                for: monthIndexPath,
                monthRect: monthRect
            )
        }

        layoutInfo[.day] = dayCellsInfo
        layoutInfo[.month] = monthsInfo
        layoutInfo[.event] = rowsInfo

        self.layoutInfo = layoutInfo
    }

    private func makeHeaderAttributes(
        for indexPath: IndexPath,  // month
        _ pageX: CGFloat,
        _ pageW: CGFloat
    ) -> UICollectionViewLayoutAttributes {
        let headerFrame = CGRect(
            x: pageX,
            y: 0,
            width: pageW,
            height: monthHeaderHeight
        )
        let attributes = UICollectionViewLayoutAttributes(
            forSupplementaryViewOfKind: ReusableConstants.Kind.monthHeader,
            with: indexPath
        )
        attributes.frame = headerFrame
        return attributes
    }

    private func makeMonthAttributes(
        for indexPath: IndexPath,
        monthRect: CGRect
    ) -> UICollectionViewLayoutAttributes {
        let attributes = UICollectionViewLayoutAttributes(
            forSupplementaryViewOfKind: ReusableConstants.Kind.monthBackground,
            with: indexPath
        )
        attributes.frame = monthRect
        attributes.zIndex = 1
        return attributes
    }

    private func makeEventAttributes(
        for indexPath: IndexPath,
        at row: Int,
        _ pageX: CGFloat,
        _ pageW: CGFloat
    ) -> UICollectionViewLayoutAttributes {
        let attributes = UICollectionViewLayoutAttributes(
            forSupplementaryViewOfKind: ReusableConstants.Kind.monthRow,
            with: indexPath
        )
        attributes.frame = CGRect(
            x: pageX,
            y: monthHeaderHeight + CGFloat(row) * weekHeight + CGFloat(row) * dayHeaderHeight
                + dayHeaderHeight,
            width: pageW,
            height: weekHeight
        )
        attributes.zIndex = 2
        return attributes
    }

    public override var collectionViewContentSize: CGSize {
        .init(width: contentWidth, height: collectionView!.bounds.height)
    }

    public override func layoutAttributesForElements(in rect: CGRect)
        -> [UICollectionViewLayoutAttributes]?
    {

        var allAttribs = [UICollectionViewLayoutAttributes]()

        for (key, attributesDict) in layoutInfo {
            print("layoutAttributesForElements key: \(key)")
            for (_, attr) in attributesDict {
                if rect.intersects(attr.frame) {
                    allAttribs.append(attr)
                }
            }
        }
        return allAttribs
    }

    public override func layoutAttributesForItem(at indexPath: IndexPath)
        -> UICollectionViewLayoutAttributes?
    {
        let dict = layoutInfo[.day]
        return dict?[indexPath]
    }

    public override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        if elementKind == ReusableConstants.Kind.monthBackground
            || elementKind == ReusableConstants.Kind.monthHeader
            || elementKind == ReusableConstants.Kind.monthWeekHeader
        {
            return layoutInfo[.month]?[indexPath]
        }
        if elementKind == ReusableConstants.Kind.monthRow {
            return layoutInfo[.event]?[indexPath]
        }
        return nil
    }

    func widthForColumnRange(_ range: NSRange) -> CGFloat {
        let availableWidth =
            collectionView!.bounds.width
        let columnWidth = availableWidth / 7

        if NSMaxRange(range) == 7 {
            return availableWidth - columnWidth * CGFloat(7 - range.length)
        }
        return columnWidth * CGFloat(range.length)
    }

    func columnWidth(_ colIndex: Int) -> CGFloat {
        widthForColumnRange(NSMakeRange(colIndex, 1))
    }

    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let oldBounds = collectionView?.bounds else { return false }
        return oldBounds.width != newBounds.width
    }
}
