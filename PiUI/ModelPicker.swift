import SwiftUI

struct ModelPicker: View {
    let models: [ModelChoice]
    let current: String
    let choose: (ModelChoice) -> Void
    let cancel: () -> Void

    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose a model")
                .font(.headline)

            TextField("Search \(models.count) models", text: $search)
                .textFieldStyle(.roundedBorder)

            if models.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                List(found, selection: .constant(nil as String?)) { model in
                    row(model)
                        .contentShape(.rect)
                        .onTapGesture { choose(model) }
                }
                .listStyle(.inset)
                .frame(minHeight: 320)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private var found: [ModelChoice] {
        models.filter { $0.matches(search) }
    }

    private func row(_ model: ModelChoice) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.name)
                    .lineLimit(1)
                Text(model.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if model.name == current {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
            Text(context(model))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 1)
    }

    private func context(_ model: ModelChoice) -> String {
        guard model.contextWindow > 0 else { return "" }
        return "\(model.contextWindow / 1000)k"
    }
}
