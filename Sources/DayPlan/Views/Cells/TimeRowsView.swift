//
//  TimeRowsView.swift
//  CalLib
//
//  Created by mwf on 2023/8/21.
//

import UIKit

protocol TimeRowsViewDelegate: AnyObject {

    func timeRowsView(
        _ timeRowsView: TimeRowsView,
        attributedStringFor timeMark: DayPlanTimeMark,
        time: TimeInterval
    ) -> NSAttributedString?
}

class TimeRowsView: UIView {

    var calendar: Calendar = .current
    var hourSlotHeight: CGFloat = 65
    var insetsHeight: CGFloat = 45
    var timeColumnWidth: CGFloat = 40
    var timeMark: TimeInterval = 0 {
        didSet {
            setNeedsDisplay()
        }
    }

    var showsCurrentTime: Bool = true {
        didSet {
            timer?.invalidate()
            timer = nil
            if showsCurrentTime {
                timer = Timer.scheduledTimer(
                    timeInterval: 60,
                    target: self,
                    selector: #selector(timeChanged),
                    userInfo: nil,
                    repeats: true
                )
            }
            setNeedsDisplay()
        }
    }

    var hourRange: NSRange = .init(location: 0, length: 24) {
        didSet {
            assert(
                hourRange.length >= 1 && NSMaxRange(hourRange) <= 24,
                "Invalid hour range: \(hourRange)"
            )
        }
    }
    var font: UIFont = .boldSystemFont(ofSize: 12)
    var timeColor: UIColor = .lightGray
    var currentTimeColor: UIColor = .red
    weak var delegate: TimeRowsViewDelegate?

    private var timer: Timer?
    private var rounding: Int = 15

    var showsHalfHourLines: Bool {
        hourSlotHeight > 100
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func timeChanged() {
        setNeedsDisplay()
    }

    private func yOffset(for time: TimeInterval, rounded: Bool) -> CGFloat {
        var time = time
        if rounded {
            time = round(time / quarter) * quarter
        }
        return (time / 3600 - Double(hourRange.location)) * hourSlotHeight + insetsHeight
    }

    private var quarter: TimeInterval {
        TimeInterval(rounding * 60)
    }

    private func string(
        for time: TimeInterval,
        rounded: Bool,
        minutesOnly: Bool
    ) -> String {
        var time = time
        if rounded {
            time = round(time / quarter) * quarter
        }

        let hour = Int((time / 3600).truncatingRemainder(dividingBy: 24))
        let minutes = Int(time.truncatingRemainder(dividingBy: 3600)) / 60

        if minutesOnly {
            return String(format: ":%02d", minutes)
        }
        return String(format: "%02d:%02d", hour, minutes)
    }

    private func attributedString(
        for timeMark: DayPlanTimeMark,
        time: TimeInterval
    ) -> NSAttributedString? {
        var attributedString = delegate?
            .timeRowsView(self, attributedStringFor: timeMark, time: time)

        if attributedString == nil {

            let str = string(
                for: time,
                rounded: timeMark != .current,
                minutesOnly: timeMark == .floating
            )

            let style = NSMutableParagraphStyle()
            style.alignment = .right

            let color = timeMark == .current ? currentTimeColor : timeColor

            attributedString = .init(
                string: str,
                attributes: [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.foregroundColor: color,
                ]
            )
        }

        return attributedString
    }

    private func canDisplayTime(_ time: TimeInterval) -> Bool {
        let hour = Int(time / 3600)
        return hour >= hourRange.location && hour <= NSMaxRange(hourRange)
    }

    override func draw(_ rect: CGRect) {
        let spacing: CGFloat = 5
        let dash: [CGFloat] = [2, 3]

        guard let context = UIGraphicsGetCurrentContext() else { return }

        let markSizeMax = CGSize(
            width: timeColumnWidth - 2.0 * spacing,
            height: .greatestFiniteMagnitude
        )

        let comps = calendar.dateComponents([.hour, .minute, .second], from: Date())
        let currentTime = TimeInterval(
            comps.hour! * 3600
                + comps.minute! * 60
                + comps.second!
        )

        let currentAttr = attributedString(for: .current, time: currentTime)
        let currentAttrSize =
            currentAttr?
            .boundingRect(
                with: markSizeMax,
                options: .usesLineFragmentOrigin,
                context: nil
            )
            .size ?? .zero

        var y = yOffset(for: currentTime, rounded: false)
        var currentTimeRect: CGRect = .zero

        if showsCurrentTime, canDisplayTime(currentTime) {
            currentTimeRect = .init(
                x: spacing,
                y: y - currentAttrSize.height * 0.5,
                width: markSizeMax.width,
                height: currentAttrSize.height
            )

            currentAttr?.draw(in: currentTimeRect)

            let lineRect = CGRect(
                x: timeColumnWidth - spacing,
                y: y,
                width: bounds.width - timeColumnWidth + spacing,
                height: 1
            )

            context.setFillColor(currentTimeColor.cgColor)
            context.fill(lineRect)
        }

        let floatingAttr = attributedString(for: .floating, time: timeMark)
        let floatingAttrSize =
            floatingAttr?
            .boundingRect(
                with: markSizeMax,
                options: .usesLineFragmentOrigin,
                context: nil
            ) ?? .zero

        y = yOffset(for: timeMark, rounded: true)

        let floatingTimeRect = CGRect(
            x: spacing,
            y: y - floatingAttrSize.height * 0.5,
            width: markSizeMax.width,
            height: floatingAttrSize.height
        )

        var drawTimeMark = timeMark != 0 && canDisplayTime(timeMark)

        let lineWidth = 1.0 / (UIScreen.current?.scale ?? 1)

        for i in hourRange.location...NSMaxRange(hourRange) {
            let timeInSeconds = TimeInterval((i % 24) * 3600)
            let headerAttr = attributedString(for: .header, time: timeInSeconds)
            let headerAttrSize =
                headerAttr?
                .boundingRect(
                    with: markSizeMax,
                    options: .usesLineFragmentOrigin,
                    context: nil
                )
                .size ?? .zero
            y =
                (CGFloat(i - hourRange.location) * hourSlotHeight + insetsHeight).aligned
                - lineWidth * 0.5

            let headerAttrRect = CGRect(
                x: spacing,
                y: y - headerAttrSize.height * 0.5,
                width: markSizeMax.width,
                height: headerAttrSize.height
            )

            if !currentTimeRect.intersects(headerAttrRect) || !showsCurrentTime {
                headerAttr?.draw(in: headerAttrRect)
            }

            context.setStrokeColor(timeColor.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineDash(phase: 0, lengths: [])
            context.move(to: .init(x: timeColumnWidth, y: y))
            context.addLine(
                to: .init(
                    x: timeColumnWidth + rect.width,
                    y: y
                )
            )
            context.strokePath()

            if showsHalfHourLines, i < NSMaxRange(hourRange) {
                y = (y + hourSlotHeight * 0.5).aligned - lineWidth * 0.5

                context.setLineDash(phase: 0, lengths: dash)
                context.move(to: .init(x: timeColumnWidth, y: y))
                context.addLine(
                    to: .init(
                        x: timeColumnWidth + rect.width,
                        y: y
                    )
                )
                context.strokePath()
            }

            drawTimeMark = !floatingTimeRect.intersects(headerAttrRect)
        }

        if drawTimeMark && timeMark > 0 {
            floatingAttr?.draw(in: floatingTimeRect)
        }
    }
}
