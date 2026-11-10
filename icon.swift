import AppKit
import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let rect = NSRect(x: 55, y: 55, width: 914, height: 914)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210)
    NSGradient(starting: NSColor(calibratedRed: 0.08, green: 0.43, blue: 0.47, alpha: 1), ending: NSColor(calibratedRed: 0.22, green: 0.67, blue: 0.61, alpha: 1))!.draw(in: shape, angle: 65)
    NSColor.white.setStroke()
    let check = NSBezierPath()
    check.move(to: NSPoint(x: 310, y: 650)); check.line(to: NSPoint(x: 450, y: 520)); check.line(to: NSPoint(x: 718, y: 765))
    check.lineWidth = 65; check.lineCapStyle = .round; check.lineJoinStyle = .round; check.stroke()
    for y in [325.0, 220.0] {
        let wave = NSBezierPath()
        wave.move(to: NSPoint(x: 245, y: y))
        wave.curve(to: NSPoint(x: 512, y: y), controlPoint1: NSPoint(x: 335, y: y+105), controlPoint2: NSPoint(x: 422, y: y-105))
        wave.curve(to: NSPoint(x: 779, y: y), controlPoint1: NSPoint(x: 602, y: y+105), controlPoint2: NSPoint(x: 689, y: y-105))
        wave.lineWidth = 35; wave.lineCapStyle = .round; wave.stroke()
    }
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let data = rep.representation(using: .png, properties: [:])!
    for base in [16, 32, 128, 256, 512] {
        if pixels == base { try data.write(to: root.appendingPathComponent("icon_\(base)x\(base).png")) }
        if pixels == base*2 { try data.write(to: root.appendingPathComponent("icon_\(base)x\(base)@2x.png")) }
    }
}
