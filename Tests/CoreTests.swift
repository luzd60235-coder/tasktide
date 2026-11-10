import Foundation

@main struct CoreTests {
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var task = TaskRecord(name: "测试任务", deadline: now.addingTimeInterval(172801), urgency: .normal)
        assert(task.effectiveUrgency(at: now) == .normal)
        task.deadline = now.addingTimeInterval(86400)
        assert(task.effectiveUrgency(at: now) == .high)
        task.deadline = now.addingTimeInterval(1)
        assert(task.timeLabel(at: now) == "剩余 1 天内")
        task.urgency = .urgent
        assert(task.effectiveUrgency(at: now) == .urgent)
        task.deadline = now.addingTimeInterval(-86401)
        assert(task.timeLabel(at: now) == "逾期 2 天")
        task.urgency = .low
        assert(task.effectiveUrgency(at: now) == .urgent)
        task.progress = 47; task.nextStep = "运行第二组实验"
        var cancelled = task; cancelled.cancel(at: now)
        assert(cancelled.state == .cancelled && cancelled.progress == 47)
        task.complete(at: now)
        assert(task.state == .completed && task.progress == 100)
        assert(task.timeLabel(at: now) == "已完成")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("tasks.json")
        let missing = try TaskDisk.load(from: path)
        assert(missing.isEmpty)
        try TaskDisk.save([task, cancelled], to: path)
        let loaded = try TaskDisk.load(from: path)
        assert(loaded.count == 2 && loaded[1].nextStep == cancelled.nextStep && loaded[1].progress == 47)
        try TaskDisk.save([task], to: path)
        let backup = try TaskDisk.load(from: path.appendingPathExtension("backup"))
        assert(backup.count == 2)
        print("PASS: deadline boundaries, escalation, overdue days, complete/cancel, JSON roundtrip and backup")
    }
}
