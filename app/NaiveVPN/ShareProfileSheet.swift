import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum NaiveQRCodeImage {
    static func uiImage(from string: String, scale: CGFloat = 12) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else {
            return nil
        }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

struct ShareProfileSheet: View {
    let shareURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var qrImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Group {
                        if let qrImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 260, maxHeight: 260)
                        } else {
                            ProgressView()
                                .frame(maxWidth: 260, minHeight: 200)
                        }
                    }
                    .padding(.top, 8)
                    .task(id: shareURL) {
                        qrImage = NaiveQRCodeImage.uiImage(from: shareURL)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tr("Link"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(shareURL)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        UIPasteboard.general.string = shareURL
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copied = false
                        }
                    } label: {
                        ZStack {
                            Image(systemName: "doc.on.doc")
                                .opacity(copied ? 0 : 1)
                            Image(systemName: "checkmark.circle.fill")
                                .opacity(copied ? 1 : 0)
                        }
                        .font(.title2)
                        .accessibilityHidden(true)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(copied ? L10n.tr("Copied") : L10n.tr("Copy"))
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .accessibilityLabel(L10n.tr("Share"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary, .tertiary)
                    }
                    .accessibilityLabel(L10n.tr("Close"))
                }
            }
        }
    }
}
