import SwiftUI
import AppKit

extension Urgency {
    var color: Color {
        switch self {
        case .low: return Color(red: 0.25, green: 0.56, blue: 0.51)
        case .normal: return Color(red: 0.26, green: 0.46, blue: 0.78)
        case .high: return Color(red: 0.79, green: 0.48, blue: 0.17)
        case .urgent: return Color(red: 0.78, green: 0.29, blue: 0.29)
        }
    }
}

@MainActor final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskRecord] = []
    @Published var error: String?
    @Published private(set) var finishing: [UUID: TaskRecord] = [:]
    @Published private(set) var shattering: Set<UUID> = []
    private var writable = true
    let url: URL
    init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if QA
        url = FileManager.default.temporaryDirectory.appendingPathComponent("TaskTide-QA/tasks.json")
        #else
        url = root.appendingPathComponent("TaskTide/tasks.json")
        #endif
        do { tasks = try TaskDisk.load(from: url) }
        catch { writable = false; self.error = "无法读取任务文件。为保护原有数据，已暂停写入。\n\(url.path)\n\(error.localizedDescription)" }
        #if QA
        if tasks.isEmpty {
            tasks = [
                TaskRecord(name: "完成论文实验", deadline: Date().addingTimeInterval(72000), urgency: .high, progress: 65, nextStep: "运行第二组消融实验，记录评价指标"),
                TaskRecord(name: "提交组会汇报", deadline: Date().addingTimeInterval(-90000), urgency: .normal, progress: 30, nextStep: "补充结果分析与下一步计划"),
                TaskRecord(name: "整理文献精读笔记", deadline: Date().addingTimeInterval(5 * 86400), urgency: .normal, progress: 40, nextStep: "整理三篇流匹配论文的核心贡献"),
                TaskRecord(name: "备份研究数据", deadline: Date().addingTimeInterval(7 * 86400), urgency: .low, progress: 10)
            ]
        }
        #endif
    }
    @discardableResult func upsert(_ task: TaskRecord) -> Bool {
        guard writable else { error = "任务文件未成功读取，暂时不能保存。"; return false }
        var updated = tasks
        if let i = updated.firstIndex(where: { $0.id == task.id }) { updated[i] = task }
        else { updated.append(task) }
        do { try TaskDisk.save(updated, to: url); tasks = updated; return true }
        catch { self.error = "保存失败，修改尚未写入磁盘：\(error.localizedDescription)"; return false }
    }
    func completeWithEffect(_ original: TaskRecord) -> Bool {
        guard finishing[original.id] == nil else { return false }
        var completed = original
        completed.complete()
        // Commit to disk first: closing the app during the effect cannot lose completion.
        guard upsert(completed) else { return false }
        var preview = original
        preview.progress = 100
        finishing[original.id] = preview
        Task { @MainActor in
            // Let the task details sheet close before breaking the card.
            try? await Task.sleep(for: .milliseconds(360))
            shattering.insert(original.id)
            try? await Task.sleep(for: .milliseconds(1080))
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                finishing.removeValue(forKey: original.id)
                shattering.remove(original.id)
            }
        }
        return true
    }
}

enum Screen: String, CaseIterable { case active = "进行中", completed = "已完成", cancelled = "废弃任务" }

@main struct TaskTideApp: App {
    @StateObject private var store = TaskStore()
    var body: some Scene {
        WindowGroup("任务潮汐") {
            Dashboard().environmentObject(store)
                .frame(minWidth: 820, minHeight: 600)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 1050, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("添加任务") { NotificationCenter.default.post(name: .newTask, object: nil) }.keyboardShortcut("n")
            }
            CommandGroup(replacing: .help) {
                Button("打开本地数据文件夹") { NSWorkspace.shared.open(store.url.deletingLastPathComponent()) }
            }
        }
    }
}
extension Notification.Name { static let newTask = Notification.Name("TaskTide.NewTask") }

struct Dashboard: View {
    @EnvironmentObject var store: TaskStore
    @State private var screen: Screen = .active
    @State private var adding = false
    @State private var selected: TaskRecord?
    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let ink = Color(red: 0.15, green: 0.22, blue: 0.29)
    private var visible: [TaskRecord] {
        let state: TaskState = screen == .active ? .active : screen == .completed ? .completed : .cancelled
        let records = store.tasks.filter { $0.state == state }
            + (screen == .active ? Array(store.finishing.values) : [])
        return records.sorted {
            if state != .active { return ($0.closedAt ?? $0.createdAt) > ($1.closedAt ?? $1.createdAt) }
            let a = $0.effectiveUrgency(at: now).rawValue, b = $1.effectiveUrgency(at: now).rawValue
            if a != b { return a > b }
            return $0.deadline < $1.deadline
        }
    }
    private var active: [TaskRecord] { store.tasks.filter { $0.state == .active } }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    Image(systemName: "water.waves").font(.system(size: 28, weight: .medium)).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("任务潮汐").font(.system(size: 23, weight: .bold, design: .rounded))
                        Text("把下一步，变成已完成。").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { screen = .cancelled } label: {
                    Label("废弃任务", systemImage: "archivebox").padding(.horizontal, 10).padding(.vertical, 9)
                }.buttonStyle(.plain)
                Button { adding = true } label: {
                    Label("添加任务", systemImage: "plus").fontWeight(.semibold)
                        .padding(.horizontal, 17).padding(.vertical, 11)
                        .foregroundStyle(.white).background(ink, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).keyboardShortcut("n")
            }.padding(.horizontal, 34).padding(.top, 35).padding(.bottom, 27)
            HStack(spacing: 16) {
                Stat(value: "\(active.count)", title: "进行中的任务", icon: "square.stack", tint: .teal)
                Stat(value: "\(active.filter { $0.deadline > now && $0.deadline.timeIntervalSince(now) <= 86400 }.count)", title: "一天内截止", icon: "clock", tint: .orange)
                Stat(value: "\(active.filter { $0.deadline <= now }.count)", title: "已逾期", icon: "exclamationmark.circle", tint: .red)
            }.padding(.horizontal, 34)
            HStack {
                HStack(spacing: 6) {
                    ForEach(Screen.allCases, id: \.self) { tab in
                        Button { screen = tab } label: {
                            Text(tab.rawValue).font(.system(size: 13, weight: screen == tab ? .semibold : .regular))
                                .padding(.horizontal, 15).padding(.vertical, 9)
                                .foregroundStyle(screen == tab ? ink : Color.secondary)
                                .background(screen == tab ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain)
                    }
                }.padding(4).background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                Spacer()
                Text(screen == .active ? "按紧急程度 · 截止时间排序" : "按归档时间排序").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(.horizontal, 34).padding(.top, 28).padding(.bottom, 17)
            if visible.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: screen == .active ? "sun.horizon" : screen == .completed ? "checkmark.seal" : "archivebox")
                        .font(.system(size: 47, weight: .ultraLight)).foregroundStyle(.teal.opacity(0.65))
                    Text(screen == .active ? "给今天一个清晰的方向" : screen == .completed ? "每一次完成，都值得留下" : "暂时没有废弃任务").font(.system(size: 21, weight: .medium))
                    Text(screen == .active ? "点击右上角「添加任务」，记下名称、截止时间和紧急程度。" : screen == .completed ? "完成的任务会归档在这里。" : "取消的任务会保存在这里，也可以恢复。").foregroundStyle(.secondary)
                    if screen == .active {
                        Button("添加第一项任务") { adding = true }.buttonStyle(.bordered).controlSize(.large)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(visible) { task in
                            ShatteringTaskCard(task: task, now: now, breaking: store.shattering.contains(task.id)) { selected = task }
                                .disabled(store.finishing[task.id] != nil)
                                .transition(.opacity)
                        }
                    }.padding(.horizontal, 34).padding(.top, 3).padding(.bottom, 24)
                        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: visible.map(\.id))
                }
            }
            HStack {
                Image(systemName: "internaldrive")
                Text("仅保存在这台 Mac · 自动保存")
                Spacer()
                Text("剩余 24 小时内自动提一级 · 逾期为紧急")
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 34).padding(.vertical, 14)
        }
        .foregroundStyle(ink)
        .background(Color(red: 0.965, green: 0.966, blue: 0.95))
        .sheet(isPresented: $adding) { AddTaskSheet().environmentObject(store) }
        .sheet(item: $selected) { task in TaskDetail(task: task).environmentObject(store) }
        .onReceive(timer) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .newTask)) { _ in adding = true }
        .alert("数据保存提示", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("知道了") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

struct Stat: View {
    let value: String; let title: String; let icon: String; let tint: Color
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(value).font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: icon).font(.system(size: 24, weight: .light)).foregroundStyle(tint.opacity(0.75))
        }.padding(19).frame(maxWidth: .infinity)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TaskCard: View {
    let task: TaskRecord; let now: Date; let action: () -> Void
    @State private var hover = false
    var priority: Urgency { task.effectiveUrgency(at: now) }
    var tint: Color { task.state == .completed ? .teal : task.state == .cancelled ? .gray : priority.color }
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.name).font(.system(size: 18, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                        Text(task.nextStep.isEmpty ? "点击任务，写下你的下一步" : "下一步：\(task.nextStep)")
                            .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 12)
                    Text("\(task.progress)%").font(.system(size: 29, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(tint)
                }
                HStack(spacing: 10) {
                    Text(task.state == .active ? priority.title : task.state == .completed ? "已完成" : "已取消")
                        .font(.system(size: 10, weight: .semibold)).padding(.horizontal, 9).padding(.vertical, 4)
                        .foregroundStyle(tint).background(tint.opacity(0.12), in: Capsule())
                    if task.state == .active && priority != task.urgency {
                        Text("自动提级").font(.system(size: 10)).foregroundStyle(tint)
                    }
                    Spacer()
                    Text(task.deadline.formatted(.dateTime.month().day().hour().minute())).font(.system(size: 11)).foregroundStyle(.secondary)
                    Label(task.timeLabel(at: now), systemImage: task.deadline <= now && task.state == .active ? "exclamationmark.circle" : "clock")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(task.deadline <= now && task.state == .active ? Color.red : tint)
                }
            }.padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        tint.opacity(0.055)
                        Rectangle().fill(tint.opacity(0.17)).frame(width: proxy.size.width * CGFloat(task.progress) / 100)
                    }
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(tint.opacity(hover ? 0.5 : 0.17), lineWidth: 1))
            .shadow(color: .black.opacity(hover ? 0.055 : 0.015), radius: hover ? 9 : 3, y: 3)
        }.buttonStyle(.plain).onHover { hover = $0 }
            .accessibilityLabel("\(task.name)，进度 \(task.progress)%，\(priority.title)，\(task.timeLabel(at: now))")
    }
}

struct AddTaskSheet: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
    @State private var urgency: Urgency = .normal
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("添加任务").font(.system(size: 25, weight: .bold))
            Text("先确定终点，再迈出下一步。").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text("任务名称").fontWeight(.medium)
                TextField("例如：完成论文实验", text: $name).textFieldStyle(.roundedBorder).controlSize(.large).focused($focused)
            }
            DatePicker("截止时间", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
            Picker("紧急程度", selection: $urgency) {
                ForEach(Urgency.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.menu)
            Text("不足 24 小时自动提一级；逾期自动升为紧急。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("添加任务") {
                    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if store.upsert(TaskRecord(name: title, deadline: deadline, urgency: urgency)) { dismiss() }
                }.buttonStyle(.borderedProminent).tint(.teal).keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(.top, 8)
        }.padding(32).frame(width: 470).onAppear { focused = true }.environment(\.locale, Locale(identifier: "zh_CN"))
    }
}

struct TaskDetail: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) var dismiss
    @State var task: TaskRecord
    @State private var editing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.name).font(.system(size: 23, weight: .bold)).textSelection(.enabled)
                    Text("截止 \(task.deadline.formatted(date: .abbreviated, time: .shortened)) · \(task.timeLabel(at: Date()))")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { editing.toggle() } label: { Image(systemName: "pencil") }.help("修改名称、截止时间和紧急程度")
            }
            if editing {
                TextField("任务名称", text: $task.name).textFieldStyle(.roundedBorder)
                DatePicker("截止时间", selection: $task.deadline)
                Picker("紧急程度", selection: $task.urgency) {
                    ForEach(Urgency.allCases) { Text($0.title).tag($0) }
                }
            }
            Divider()
            // The four task actions follow the user's requested order.
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("01  完成进度").fontWeight(.medium)
                    Spacer()
                    TextField("百分比", value: $task.progress, format: .number).frame(width: 55).textFieldStyle(.roundedBorder)
                        .onChange(of: task.progress) { _, value in task.progress = min(100, max(0, value)) }
                    Text("%")
                }
                Slider(value: Binding(get: { Double(task.progress) }, set: { task.progress = Int($0) }), in: 0...100, step: 1).tint(task.urgency.color)
                Text("保存后，百分比会从左向右填满任务卡片背景。100% 进度仍需点击完成来归档。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }.disabled(task.state != .active)
            VStack(alignment: .leading, spacing: 10) {
                Text("02  下一步").fontWeight(.medium)
                TextField("写下一个具体、可执行的动作", text: $task.nextStep, axis: .vertical)
                    .lineLimit(2...4).textFieldStyle(.roundedBorder).disabled(task.state != .active)
            }
            Divider()
            if task.state == .active {
                Button {
                    if store.completeWithEffect(task) { dismiss() }
                } label: { Label(Date() < task.deadline ? "03  提前完成" : "03  完成任务", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity, alignment: .leading).padding(10) }
                    .buttonStyle(.bordered).tint(.teal)
                Button {
                    task.cancel(); if store.upsert(task) { dismiss() }
                } label: { Label("04  取消任务", systemImage: "archivebox").frame(maxWidth: .infinity, alignment: .leading).padding(10) }
                    .buttonStyle(.bordered).tint(.red)
                Text("取消后会移入右上角的「废弃任务」，可以恢复。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Button("恢复为进行中任务") {
                    task.state = .active; task.closedAt = nil
                    if task.progress == 100 { task.progress = 0 }
                    if store.upsert(task) { dismiss() }
                }.buttonStyle(.bordered)
            }
            HStack {
                Button("返回") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                if task.state == .active {
                    Button("保存并返回") {
                        task.name = task.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if store.upsert(task) { dismiss() }
                    }.buttonStyle(.borderedProminent).tint(.teal).keyboardShortcut(.defaultAction)
                        .disabled(task.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(.top, 8)
        }.padding(30).frame(width: 530).environment(\.locale, Locale(identifier: "zh_CN"))
    }
}
