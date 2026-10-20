import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: AppStore
    @State private var visibleMonth = Date.now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private let grid = CalendarGrid()

    var body: some View {
        let byDay = grid.draftsByDay(store.scheduledDrafts)
        HSplitView {
            VStack(spacing: 12) {
                header
                monthGrid(byDay)
            }
            .padding()
            .frame(minWidth: 520)

            DayPanel(day: selectedDay, drafts: byDay[selectedDay] ?? [])
                .frame(minWidth: 280, idealWidth: 320)
        }
        .navigationTitle("Calendar")
        .task {
            if store.lastDraftRefreshAt == nil { await store.refreshDrafts() }
        }
    }

    private var header: some View {
        HStack {
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                .font(.largeTitle.bold())
            Spacer()
            Button {
                visibleMonth = grid.month(offsetBy: -1, from: visibleMonth)
            } label: { Image(systemName: "chevron.left") }
            Button("Today") {
                visibleMonth = .now
                selectedDay = Calendar.current.startOfDay(for: .now)
            }
            Button {
                visibleMonth = grid.month(offsetBy: 1, from: visibleMonth)
            } label: { Image(systemName: "chevron.right") }
        }
    }

    private func monthGrid(_ byDay: [Date: [SubstackDraft]]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(spacing: 4) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(grid.cells(forMonthContaining: visibleMonth).enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(
                            day: day,
                            drafts: byDay[day] ?? [],
                            isSelected: day == selectedDay,
                            isToday: Calendar.current.isDateInToday(day)
                        )
                        .onTapGesture { selectedDay = day }
                    } else {
                        Color.clear.frame(height: 86)
                    }
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let drafts: [SubstackDraft]
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(day.formatted(.dateTime.day()))
                .font(.callout.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.accentColor : .primary)
            ForEach(drafts.prefix(2)) { draft in
                Text(draft.calendarLabel)
                    .font(.caption2)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            }
            if drafts.count > 2 {
                Text("+\(drafts.count - 2) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 86, maxHeight: 86, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }
}

private struct DayPanel: View {
    @EnvironmentObject private var store: AppStore
    let day: Date
    let drafts: [SubstackDraft]
    @State private var text = ""
    @State private var time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var result = ""
    @State private var isWorking = false

    private var scheduledAt: Date {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(bySettingHour: parts.hour ?? 9, minute: parts.minute ?? 0, second: 0, of: day)!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day.formatted(date: .complete, time: .omitted))
                .font(.headline)

            if drafts.isEmpty {
                Text("Nothing scheduled.")
                    .foregroundStyle(.secondary)
            } else {
                List(drafts) { draft in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.triggerAt!.formatted(date: .omitted, time: .shortened))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(draft.body ?? "(no text)")
                            .lineLimit(4)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.inset)
                .frame(minHeight: 120)
            }

            Divider()

            Text("Schedule a Note").font(.subheadline.weight(.semibold))
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
            HStack {
                Button("Schedule") { schedule() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(isWorking || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || scheduledAt <= .now)
                if isWorking { ProgressView().controlSize(.small) }
            }
            if scheduledAt <= .now {
                Text("Pick a future time.").font(.caption).foregroundStyle(.secondary)
            }
            if !result.isEmpty {
                Text(result).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .onChange(of: day) { result = "" }
    }

    private func schedule() {
        isWorking = true
        let note = text
        let at = scheduledAt
        Task {
            do {
                try await store.publishManualNote(note, scheduledAt: at)
                text = ""
                result = "Scheduled for \(at.formatted(date: .abbreviated, time: .shortened))."
            } catch {
                result = error.localizedDescription
            }
            isWorking = false
        }
    }
}

private extension SubstackDraft {
    var calendarLabel: String {
        let time = triggerAt?.formatted(date: .omitted, time: .shortened) ?? ""
        let firstLine = body?.split(whereSeparator: \.isNewline).first.map(String.init) ?? "Note"
        return "\(time) \(firstLine)"
    }
}
