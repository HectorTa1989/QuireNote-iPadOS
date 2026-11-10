import Foundation

public struct QuirePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct QuireSize: Codable, Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct QuireRect: Codable, Equatable, Sendable {
    public var origin: QuirePoint
    public var size: QuireSize

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = QuirePoint(x: x, y: y)
        self.size = QuireSize(width: width, height: height)
    }
}

public struct TemplateLine: Equatable, Sendable {
    public var start: QuirePoint
    public var end: QuirePoint
    public var role: Role

    public enum Role: String, Sendable {
        case rule
        case margin
        case dot
    }

    public init(start: QuirePoint, end: QuirePoint, role: Role) {
        self.start = start
        self.end = end
        self.role = role
    }
}

public enum TemplateGeometry {
    public static let pointsPerMillimetre = 72.0 / 25.4

    public static func pageSize(for paper: Paper) -> QuireSize {
        switch paper.size {
        case .a4:
            QuireSize(width: 210 * pointsPerMillimetre, height: 297 * pointsPerMillimetre)
        case .usLetter:
            QuireSize(width: 8.5 * 72, height: 11 * 72)
        }
    }

    public static func lines(for paper: Paper) -> [TemplateLine] {
        let page = pageSize(for: paper)
        let spacing = 7 * pointsPerMillimetre
        let inset = 12 * pointsPerMillimetre

        switch paper.kind {
        case .blank:
            return []
        case .lined:
            return horizontalRules(page: page, spacing: spacing, inset: inset)
        case .grid:
            return horizontalRules(page: page, spacing: spacing, inset: inset)
                + verticalRules(page: page, spacing: spacing, inset: inset)
        case .dotted:
            return dots(page: page, spacing: spacing, inset: inset)
        case .cornell:
            let rules = horizontalRules(page: page, spacing: spacing, inset: inset)
            let cueX = page.width * 0.30
            let summaryY = page.height * 0.82
            return rules + [
                TemplateLine(
                    start: QuirePoint(x: cueX, y: inset),
                    end: QuirePoint(x: cueX, y: summaryY),
                    role: .margin
                ),
                TemplateLine(
                    start: QuirePoint(x: inset, y: summaryY),
                    end: QuirePoint(x: page.width - inset, y: summaryY),
                    role: .margin
                ),
            ]
        }
    }

    private static func horizontalRules(page: QuireSize, spacing: Double, inset: Double) -> [TemplateLine] {
        stride(from: inset, through: page.height - inset, by: spacing).map { y in
            TemplateLine(
                start: QuirePoint(x: inset, y: y),
                end: QuirePoint(x: page.width - inset, y: y),
                role: .rule
            )
        }
    }

    private static func verticalRules(page: QuireSize, spacing: Double, inset: Double) -> [TemplateLine] {
        stride(from: inset, through: page.width - inset, by: spacing).map { x in
            TemplateLine(
                start: QuirePoint(x: x, y: inset),
                end: QuirePoint(x: x, y: page.height - inset),
                role: .rule
            )
        }
    }

    private static func dots(page: QuireSize, spacing: Double, inset: Double) -> [TemplateLine] {
        var result: [TemplateLine] = []
        for y in stride(from: inset, through: page.height - inset, by: spacing) {
            for x in stride(from: inset, through: page.width - inset, by: spacing) {
                let point = QuirePoint(x: x, y: y)
                result.append(TemplateLine(start: point, end: point, role: .dot))
            }
        }
        return result
    }
}
