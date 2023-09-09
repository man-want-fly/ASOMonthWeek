//
//  EventsRowView.swift
//  CalLib
//
//  Created by mwf on 2023/8/12.
//

import UIKit

public protocol EventsRowViewDelegate: UIScrollViewDelegate {

    func eventsRowView(_ eventsRowView: EventsRowView, numberOfEventsForDayAtIndex day: Int) -> Int
    func eventsRowView(_ eventsRowView: EventsRowView, rangeForEventAt indexPath: IndexPath)
        -> NSRange
    func eventsRowView(_ eventsRowView: EventsRowView, cellForEventAt indexPath: IndexPath)
        -> EventView

    func eventsRowView(_ eventsRowView: EventsRowView, widthForDayRange range: NSRange) -> CGFloat
    func eventsRowView(_ eventsRowView: EventsRowView, shouldSelectCellAt indexPath: IndexPath)
        -> Bool
    func eventsRowView(_ eventsRowView: EventsRowView, didSelectCellAt indexPath: IndexPath)
    func eventsRowView(_ eventsRowView: EventsRowView, shouldDeselectCellAt indexPath: IndexPath)
        -> Bool
    func eventsRowView(_ eventsRowView: EventsRowView, didDeselectCellAt indexPath: IndexPath)
    func eventsRowView(
        _ eventsRowView: EventsRowView,
        willDisplay cell: EventView,
        forEventAt indexPath: IndexPath
    )
    func eventsRowView(
        _ eventsRowView: EventsRowView,
        didEndDisplaying cell: EventView,
        forEventAt indexPath: IndexPath
    )
}

public class EventsRowView: UIScrollView, ReusableObject {
    public var reuseIdentifier: String = "EventsRowView"
    var referenceDate: Date?
    var daysRange: NSRange = .init()
    var dayWidth: CGFloat = 100
    var itemHeight: CGFloat = 18
    weak var eventsRowDelegate: EventsRowViewDelegate?
    var maxVisibleLines: Int {
        Int((bounds.height + cellSpacing + 1) / (itemHeight + cellSpacing))
    }

    private var cells: [IndexPath: EventView] = [:]
    private var labels: [UILabel] = []

    private var eventsCount: [Int: Int] = [:]
    
    private let cellSpacing: CGFloat = 2  // space around cells

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentSize = .init(width: frame.width, height: 400)
        backgroundColor = .clear
        autoresizingMask = [.flexibleHeight, .flexibleWidth]
        clipsToBounds = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        reload()
    }

    public func prepareForReuse() {
        recycleEventsCells()
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let pt = recognizer.location(in: self)

        for (indexPath, cell) in cells {
            if cell.frame.contains(pt) {
                didTap(cell, at: indexPath)
                break
            }
        }
    }

    private func didTap(_ cell: EventView, at indexPath: IndexPath) {
        if cell.selected {
            var shouldDeselect = true

            if let eventsRowDelegate {
                shouldDeselect = eventsRowDelegate.eventsRowView(
                    self,
                    shouldDeselectCellAt: indexPath
                )
            }

            if shouldDeselect {
                cell.selected = false
                eventsRowDelegate?.eventsRowView(self, didDeselectCellAt: indexPath)
            }
        } else {
            var shouldSelect = true
            if let eventsRowDelegate {
                shouldSelect = eventsRowDelegate.eventsRowView(self, shouldSelectCellAt: indexPath)
            }

            if shouldSelect {
                cell.selected = true
                eventsRowDelegate?.eventsRowView(self, didSelectCellAt: indexPath)
            }
        }
    }

    private func maxVisibleLinesForDays(in range: NSRange) -> Int {
        var count = 0
        for day in range.location..<NSMaxRange(range) {
            count = max(count, numberOfEventsForDay(at: day))
        }
        // if count > max, we have to keep one row to show "x more events"
        return count > maxVisibleLines ? maxVisibleLines - 1 : count
    }

    private func numberOfEventsForDay(at index: Int) -> Int {
        if let count = eventsCount[index] {
            return count
        } else {
            let numEvents = eventsRowDelegate!
                .eventsRowView(self, numberOfEventsForDayAtIndex: index)
            self.eventsCount[index] = numEvents
            return numEvents
        }
    }

    private func eventRanges() -> [IndexPath: NSValue] {
        var items: [IndexPath: NSValue] = [:]

        for day in daysRange.location..<NSMaxRange(daysRange) {
            let eventsCount = numberOfEventsForDay(at: day)

            for item in 0..<eventsCount {
                let path = IndexPath(item: item, section: day)
                let eventRange = eventsRowDelegate?.eventsRowView(self, rangeForEventAt: path)

                // keep only those events starting at current column,
                // or those started earlier if this is the first day of the row range
                if let eventRange, eventRange.location == day || day == daysRange.location {
                    let rangeEventInRow = NSIntersectionRange(eventRange, daysRange)
                    items[path] = NSValue(range: rangeEventInRow)
                }
            }
        }

        return items
    }

    private func recycleEventsCells() {
        for path in cells.keys {
            let cell = cells[path]
            cell?.removeFromSuperview()
            
            if let eventsRowDelegate {
                eventsRowDelegate.eventsRowView(self, didEndDisplaying: cell!, forEventAt: path)
            }
        }
        cells.removeAll()

        for label in labels {
            label.removeFromSuperview()
        }
        labels.removeAll()
    }

    func reload() {
        recycleEventsCells()
        eventsCount.removeAll()

        let eventRanges = eventRanges()
        // dictionary of "more events" labels [ { day : count of hidden events }, ... ]
        var daysWithMoreEvents = [Int: Int]()

        // arrange events on lines
        var lines = [NSMutableIndexSet]()

        for indexPath in eventRanges.keys.sorted(by: <) {

            let eventRange = eventRanges[indexPath]!.rangeValue

            var numLine = -1  // index of the line where to insert the event (i.e the group of cells)

            for i in 0..<lines.count {
                let indexes = lines[i]
                if !indexes.intersects(in: eventRange) {
                    numLine = i  // found the right line !
                    break
                }
            }
            if numLine == -1 {  // meaning no line was yet created, or the group does not fit any
                numLine = lines.count
                lines.append(NSMutableIndexSet(indexesIn: eventRange))
            } else {
                lines[numLine].add(in: eventRange)
            }

            let maxVisibleEvents = maxVisibleLinesForDays(in: eventRange)
            if numLine < maxVisibleEvents {
                let cell = eventsRowDelegate!.eventsRowView(self, cellForEventAt: indexPath)
                cell.frame = rectForCell(eventRange, line: numLine)

                eventsRowDelegate?.eventsRowView(self, willDisplay: cell, forEventAt: indexPath)

                addSubview(cell)
                cell.setNeedsDisplay()

                cells[indexPath] = cell
            } else {
                for day in eventRange.location..<NSMaxRange(eventRange) {
                    var count = daysWithMoreEvents[Int(day)] ?? 0
                    count += 1
                    daysWithMoreEvents[Int(day)] = count
                }
            }
        }

        for day in daysRange.location..<NSMaxRange(daysRange) {
            if let hiddenCount = daysWithMoreEvents[Int(day)], hiddenCount > 0 {
                let label = UILabel(frame: CGRect.zero)
                label.text = String(
                    format: NSLocalizedString("%lu more...", comment: ""),
                    hiddenCount
                )
                label.textColor = UIColor.gray
                label.textAlignment = .right
                label.font = UIFont.systemFont(ofSize: 11)
                label.frame = rectForCell(NSMakeRange(day, 1), line: maxVisibleLines - 1)

                addSubview(label)
                labels.append(label)
            }
        }
    }

    func cells(in rect: CGRect) -> [EventView] {
        var items: [EventView] = []
        for (_, cell) in cells {
            if cell.frame.intersects(rect) {
                items.append(cell)
            }
        }
        return items
    }

    func indexPathForCell(at point: CGPoint) -> IndexPath? {
        for (indexPath, cell) in cells {
            if cell.frame.contains(point) {
                return indexPath
            }
        }
        return nil
    }

    func cell(at indexPath: IndexPath) -> EventView? {
        cells[indexPath]
    }

    private func rectForCell(_ range: NSRange, line: Int) -> CGRect {
        let colStart = range.location - daysRange.location

        var x = dayWidth * CGFloat(colStart)
        if let eventsRowDelegate {
            x = eventsRowDelegate.eventsRowView(self, widthForDayRange: NSMakeRange(0, colStart))
        }

        let y = CGFloat(line) * (itemHeight + cellSpacing)

        var width = dayWidth * CGFloat(range.length)
        if let eventsRowDelegate {
            width = eventsRowDelegate.eventsRowView(
                self,
                widthForDayRange: NSMakeRange(colStart, range.length)
            )
        }

        let rect = CGRect(x: x, y: y, width: width, height: self.itemHeight)
        return rect.insetBy(dx: cellSpacing, dy: 0)
    }
}
