import SwiftUI

/// The design's popover: a 250px blueprint panel above the model button. It lists four
/// models; we have around 350, so it also searches.
struct ModelPicker: View {
    let models: [ModelChoice]
    let current: String
    let choose: (ModelChoice) -> Void

    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "model", size: 12, color: Palette.neutral(700))
                .padding(.horizontal, Space.three)
                .padding(.top, Space.three)
                .padding(.bottom, Space.two)

            TextField("Search", text: $search)
                .textFieldStyle(.plain)
                .font(Typeface.body(12))
                .padding(.horizontal, Space.three)
                .padding(.bottom, Space.two)

            Hairline()

            if models.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(Space.four)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(found) { model in
                            Row(model: model, selected: model.name == current) {
                                choose(model)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 250)
        .background(Palette.neutral(100))
    }

    private var found: [ModelChoice] {
        models.filter { $0.matches(search) }
    }

    private struct Row: View {
        let model: ModelChoice
        let selected: Bool
        let pick: () -> Void

        @State private var hovering = false

        var body: some View {
            Button(action: pick) {
                HStack(spacing: Space.two) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.name)
                            .font(Typeface.body(12))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                        Text(model.id)
                            .font(Typeface.mono(10))
                            .foregroundStyle(Palette.neutral(600))
                            .lineLimit(1)
                            .truncationMode(.head)
                    }

                    Spacer(minLength: Space.one)

                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.accent)
                    }
                }
                .padding(.horizontal, Space.three)
                .padding(.vertical, Space.two)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(hovering ? Palette.accent(100) : .clear)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }
}
