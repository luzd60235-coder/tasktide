import Foundation

enum Urgency: Int, Codable, CaseIterable, Identifiable {
    case low, normal, high, urgent
    var id: Int { rawValue }
    var title: String { ["从容", "普通", "重要", "紧急"][rawValue] }
}
enum TaskState: String, Codable { case active, completed, cancelled }
struct TaskRecord: Codable, Identifiable {
    var id = UUID()
    var name: String
    var deadline: Date
    var urgency: Urgency
    var progress: Int = 0
    var nextStep: String = ""
    var state: TaskState = .active
    var createdAt: Date = Date()
    var closedAt: Date?

    func effectiveUrgency(at now: Date) -> Urgency {
        guard state == .active else { return urgency }
        let remaining = deadline.timeIntervalSince(now)
        if remaining <= 0 { return .urgent }
        if remaining <= 86400 { return Urgency(rawValue: min(3, urgency.rawValue + 1))! }
        return urgency
    }
    func timeLabel(at now: Date) -> String {
        if state == .completed { return "已完成" }
        if state == .cancelled { return "已取消" }
        let seconds = deadline.timeIntervalSince(now)
        if seconds <= 0 { return "逾期 \(max(1, Int(ceil(-seconds / 86400)))) 天" }
        if seconds <= 86400 { return "剩余 1 天内" }
        return "剩余 \(Int(ceil(seconds / 86400))) 天"
    }
    mutating func complete(at now: Date = Date()) {
        progress = 100; state = .completed; closedAt = now
    }
    mutating func cancel(at now: Date = Date()) { state = .cancelled; closedAt = now }
}

enum TaskDisk {
    static func load(from url: URL) throws -> [TaskRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([TaskRecord].self, from: Data(contentsOf: url))
    }
    static func save(_ tasks: [TaskRecord], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(tasks)
        // Keep the previous successful file as a local recovery copy.
        if FileManager.default.fileExists(atPath: url.path) {
            let previous = try Data(contentsOf: url)
            try previous.write(to: url.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }
}
