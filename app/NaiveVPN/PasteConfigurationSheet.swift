import SwiftUI
import UIKit

struct PasteConfigurationSheet: View {
    let onImport: (String) throws -> Void
    let onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                } header: {
                    Text(L10n.tr("Paste a share link or JSON configuration."))
                }

                Section {
                    Button {
                        if let s = UIPasteboard.general.string {
                            text = s
                        }
                    } label: {
                        Label(L10n.tr("Paste from Clipboard"), systemImage: "doc.on.clipboard")
                    }
                }
            }
            .navigationTitle(L10n.tr("Import"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("Import")) {
                        importTapped()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func importTapped() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        do {
            try onImport(trimmed)
            dismiss()
        } catch {
            onError(error.localizedDescription)
        }
    }
}
