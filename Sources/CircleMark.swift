//
//  CircleMark.swift
//  CalLib
//
//  Created by mwf on 2023/8/23.
//

import UIKit

let circleMarkAttributeName = "CircleMarkAttributeName"

class CircleMark {

    var borderColor: UIColor = .clear  // default is clear
    var color: UIColor = .red  // default is red
    var margin: CGFloat = 0  // padding on each side of the text
    var yOffset: CGFloat = 0  // vertical position adjustment
}

extension NSAttributedString {

    func image(withCircleMark mark: CircleMark) -> UIImage? {
        let maxSize = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        var strRect = boundingRect(
            with: maxSize,
            options: .usesLineFragmentOrigin,
            context: nil
        )
        let markWidth = max(strRect.width, strRect.height) + 2.0 * mark.margin
        let markRect = CGRect(x: 0, y: 0, width: markWidth, height: markWidth)

        UIGraphicsBeginImageContextWithOptions(markRect.size, false, 0.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.saveGState()

        ctx.setStrokeColor(mark.borderColor.cgColor)
        ctx.setFillColor(mark.color.cgColor)

        ctx.addEllipse(in: markRect.insetBy(dx: 1, dy: 1))
        ctx.drawPath(using: .fillStroke)

        strRect.origin = CGPoint(
            x: markWidth / 2.0 - strRect.width / 2.0,
            y: markWidth / 2.0 - strRect.height / 2.0
        )
        draw(with: strRect, options: .usesLineFragmentOrigin, context: nil)

        ctx.restoreGState()

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return img
    }

    func attributedString(
        withProcessedCircleMarksInRange range: NSRange
    ) -> NSAttributedString {
        let attrStr = mutableCopy() as! NSMutableAttributedString
        attrStr.processCircleMarks(inRange: range)
        return attrStr
    }

}

extension NSMutableAttributedString {

    func processCircleMarks(inRange range: NSRange) {
        enumerateAttribute(
            NSAttributedString.Key(rawValue: circleMarkAttributeName),
            in: range,
            options: [],
            using: { value, subrange, _ in
                if let circleMark = value as? CircleMark {
                    let subAttrStr = attributedSubstring(from: subrange)
                    if let image = subAttrStr.image(withCircleMark: circleMark) {
                        let attachment = NSTextAttachment()
                        attachment.image = image
                        attachment.bounds = CGRect(
                            x: circleMark.margin,
                            y: circleMark.yOffset,
                            width: attachment.image?.size.width ?? 0,
                            height: attachment.image?.size.height ?? 0
                        )
                        let imgStr = NSAttributedString(attachment: attachment)
                        replaceCharacters(in: subrange, with: imgStr)
                    }
                }
            }
        )
    }
}
