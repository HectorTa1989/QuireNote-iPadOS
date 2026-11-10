import QuireCore
import SwiftUI

struct TemplatePageView: View {
    let paper: Paper

    var body: some View {
        Canvas { context, size in
            let pageSize = TemplateGeometry.pageSize(for: paper)
            let scaleX = size.width / pageSize.width
            let scaleY = size.height / pageSize.height

            for line in TemplateGeometry.lines(for: paper) {
                let start = CGPoint(x: line.start.x * scaleX, y: line.start.y * scaleY)
                let end = CGPoint(x: line.end.x * scaleX, y: line.end.y * scaleY)
                switch line.role {
                case .dot:
                    let rect = CGRect(x: start.x - 0.75, y: start.y - 0.75, width: 1.5, height: 1.5)
                    context.fill(Path(ellipseIn: rect), with: .color(.secondary.opacity(0.42)))
                case .rule, .margin:
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(
                        path,
                        with: .color(line.role == .margin ? .red.opacity(0.35) : .blue.opacity(0.20)),
                        lineWidth: line.role == .margin ? 1 : 0.75
                    )
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
