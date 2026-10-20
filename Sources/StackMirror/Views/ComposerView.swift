import SwiftUI

struct ComposerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var text = ""
    @State private var schedule = false
    @State private var scheduledAt = Date.now.addingTimeInterval(3600)
    @State private var result = ""
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Note Composer").font(.largeTitle.bold())
                    Text("Publish now or create a native scheduled Substack draft.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Test Connection") {
                    run {
                        try await store.publishTestNote()
                        result = "Test Note published."
                    }
                }
            }

            TextEditor(text: $text)
                .font(.body)
                .padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.quaternary) }
                .frame(minHeight: 260)

            HStack {
                Toggle("Schedule", isOn: $schedule)
                if schedule {
                    DatePicker(
                        "Publish at",
                        selection: $scheduledAt,
                        in: Date.now...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                Spacer()
                if isWorking { ProgressView().controlSize(.small) }
                Button(schedule ? "Schedule Note" : "Publish Note") {
                    let note = text
                    run {
                        try await store.publishManualNote(
                            note,
                            scheduledAt: schedule ? scheduledAt : nil
                        )
                        result = schedule ? "Note scheduled." : "Note published."
                        text = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
            }

            if !result.isEmpty {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.hasPrefix("Failed") ? .red : .green)
            }
        }
        .padding(24)
        .navigationTitle("Composer")
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await action()
            } catch {
                result = "Failed: \(error.localizedDescription)"
            }
        }
    }
}
