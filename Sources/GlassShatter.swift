import SwiftUI
import AppKit

private struct GlassShard: Identifiable {
    let id: Int
    let points: [CGPoint]
    var center: CGPoint {
        CGPoint(x: points.map(\.x).reduce(0,+) / 3, y: points.map(\.y).reduce(0,+) / 3)
    }
    // A jittered triangular mesh: neighbouring shards share the same edges.
    static let mesh: [GlassShard] = {
        let columns = 11, rows = 3
        func noise(_ a: Int, _ b: Int) -> CGFloat {
            let n = sin(Double(a * 127 + b * 311 + 19)) * 43758.5453
            return CGFloat(n - floor(n))
        }
        var vertices: [[CGPoint]] = []
        for row in 0...rows {
            vertices.append((0...columns).map { column in
                let x = CGFloat(column) / CGFloat(columns)
                let y = CGFloat(row) / CGFloat(rows)
                return CGPoint(x: x + (column == 0 || column == columns ? 0 : (noise(row,column)-0.5) * 0.065),
                               y: y + (row == 0 || row == rows ? 0 : (noise(column,row)-0.5) * 0.22))
            })
        }
        var shards: [GlassShard] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let a = vertices[row][column], b = vertices[row][column+1]
                let c = vertices[row+1][column], d = vertices[row+1][column+1]
                let triangles = (row+column).isMultiple(of: 2) ? [[a,b,c],[b,d,c]] : [[a,b,d],[a,d,c]]
                for points in triangles { shards.append(GlassShard(id: shards.count, points: points)) }
            }
        }
        return shards
    }()
}

struct ShatteringTaskCard: View {
    let task: TaskRecord
    let now: Date
    let breaking: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: NSImage?
    @State private var started: Date?
    @State private var measured = CGSize.zero

    var body: some View {
        TaskCard(task: task, now: now, action: action)
            .opacity(started == nil ? 1 : 0)
            .background(GeometryReader { proxy in
                Color.clear.onAppear { measured = proxy.size }
                    .onChange(of: proxy.size) { _, size in measured = size }
            })
            .overlay {
                if let image, let started {
                    TimelineView(.animation) { timeline in
                        let t = min(1, max(0, timeline.date.timeIntervalSince(started) / 0.96))
                        Canvas { context, size in
                            let picture = Image(nsImage: image)
                            let bounds = CGRect(origin: .zero, size: size)
                            if reduceMotion {
                                context.opacity = 1-t
                                context.draw(picture, in: bounds)
                            } else {
                                for shard in GlassShard.mesh {
                                    let center = CGPoint(x: shard.center.x * size.width, y: shard.center.y * size.height)
                                    let seed = Double(shard.id)
                                    let delay = Double(shard.id % 5) * 0.014
                                    let local = max(0, min(1, (t-delay) / (1-delay)))
                                    let ease = local * local
                                    let dx = (shard.center.x - 0.5) * (100 + CGFloat(shard.id % 7) * 15) * local
                                    let dy = -sin(seed * 2.3) * 34 * local + 160 * ease
                                    let angle = sin(seed * 1.7) * 1.3 * local
                                    var piece = context
                                    piece.opacity = max(0, 1 - pow(local, 1.6))
                                    piece.translateBy(x: center.x + dx, y: center.y + dy)
                                    piece.rotate(by: .radians(angle))
                                    piece.scaleBy(x: 1 - 0.2 * local, y: max(0.15, abs(cos(seed * 0.7 + local * 2.0)) * local + (1-local)))
                                    piece.translateBy(x: -center.x, y: -center.y)
                                    var path = Path()
                                    path.addLines(shard.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                                    path.closeSubpath()
                                    piece.clip(to: path)
                                    piece.draw(picture, in: bounds)
                                    // Brief bright fracture lines catch the light like glass.
                                    piece.stroke(path, with: .color(.white.opacity(0.85 * (1-local))), lineWidth: 1.4)
                                }
                            }
                        }
                    }.allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .onChange(of: breaking) { _, value in
                guard value, started == nil, measured.width > 0 else { return }
                let renderer = ImageRenderer(content:
                    TaskCard(task: task, now: now, action: {})
                        .foregroundStyle(Color(red: 0.15, green: 0.22, blue: 0.29))
                        .frame(width: measured.width, height: measured.height)
                        .environment(\.colorScheme, .light))
                renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
                image = renderer.nsImage
                if image != nil { started = Date() }
            }
    }
}
