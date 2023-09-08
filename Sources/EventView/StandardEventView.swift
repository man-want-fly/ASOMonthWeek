//
//  StandardEventView.swift
//  CalLib
//
//  Created by mwf on 2023/8/14.
//

import UIKit

struct StandardEventViewStyle: OptionSet {

    let rawValue: Int

    static let `default`: StandardEventViewStyle = []
    static let plain = StandardEventViewStyle(rawValue: 1 << 0)
    static let border = StandardEventViewStyle(rawValue: 1 << 1)
    static let subtitle = StandardEventViewStyle(rawValue: 1 << 2)
    static let detail = StandardEventViewStyle(rawValue: 1 << 3)
}

class StandardEventView: EventView {

    var title: String?
    var subtitle: String?
    var detail: String?
    var color: UIColor = .red {
        didSet {
            resetColors()
        }
    }
    var style: StandardEventViewStyle = [.plain, .border, .detail]
    var font: UIFont = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)

    private lazy var leftBorderView = UIView()

    private var attrString = NSMutableAttributedString()

    required init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(leftBorderView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        leftBorderView.frame = .init(
            x: 0,
            y: 0,
            width: 2,
            height: bounds.height
        )

        setNeedsDisplay()
    }

    override var selected: Bool {
        didSet {
            resetColors()
        }
    }

    override var visibleHeight: CGFloat {
        didSet {
            setNeedsDisplay()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {

        let space: CGFloat = 2

        var drawRect = rect.insetBy(dx: space, dy: space)

        if style.contains(.border) {
            drawRect.origin.x += space
            drawRect.size.width -= space
        }

        redrawStringInRect(rect: drawRect)

        let boundingRect = attrString.boundingRect(
            with: CGSize(width: drawRect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        )
        drawRect.size.height = min(drawRect.height, visibleHeight)

        if boundingRect.height > drawRect.height {
            attrString.mutableString.replaceOccurrences(
                of: "\n",
                with: "  ",
                options: [.caseInsensitive],
                range: NSMakeRange(0, attrString.length)
            )
        }

        attrString.draw(
            with: drawRect,
            options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
            context: nil
        )
    }

    private func resetColors() {
        leftBorderView.backgroundColor = color
        if selected {
            backgroundColor = selected ? color : color.withAlphaComponent(0.3)
        } else if style.contains(.plain) {
            backgroundColor = color.withAlphaComponent(0.3)
        } else {
            backgroundColor = .clear
        }

        setNeedsDisplay()
    }

    private func redrawStringInRect(rect: CGRect) {
        // attributed string can't be created with nil string
        var s = ""

        if let title {
            s.append(title)
        }

        let boldFont = UIFont(
            descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!,
            size: font.pointSize
        )

        let str = NSMutableAttributedString(
            string: s,
            attributes: [NSAttributedString.Key.font: boldFont]
        )

        if let subtitle, !subtitle.isEmpty, style.contains(.subtitle) {
            let s = "\n\(subtitle)"
            let subtitle = NSMutableAttributedString(
                string: s,
                attributes: [NSAttributedString.Key.font: font]
            )
            str.append(subtitle)
        }

        if let detail, !detail.isEmpty, style.contains(.detail) {
            let smallFont = UIFont(descriptor: font.fontDescriptor, size: font.pointSize - 2)
            let s = "\t\(detail)"
            let detail = NSMutableAttributedString(
                string: s,
                attributes: [NSAttributedString.Key.font: smallFont]
            )
            str.append(detail)
        }

        let t = NSTextTab(textAlignment: .right, location: rect.width, options: [:])
        let style = NSMutableParagraphStyle()
        style.tabStops = [t]
        str.addAttribute(
            NSAttributedString.Key.paragraphStyle,
            value: style,
            range: NSMakeRange(0, str.length)
        )

        let color = selected ? .white : color
        str.addAttribute(
            .foregroundColor,
            value: color,
            range: NSMakeRange(0, str.length)
        )

        attrString = str
    }
}
