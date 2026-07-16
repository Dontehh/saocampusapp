//
//  QRCodeView.swift
//  Campus
//
//  Generates a CIQRCodeGenerator code that encodes the check-in URL.
//  Students would scan with their native camera to open the form;
//  manual entry below mirrors the same submit logic for in-app testing.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct QRCodeView: View {
    let eventId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DataStore

    @State private var studentId   = ""
    @State private var feedback:    FeedbackMessage?

    private let context = CIContext()
    private let filter  = CIFilter.qrCodeGenerator()

    /// The shared SAO Microsoft Forms check-in URL. Every event's QR encodes
    /// this same link; the form collects the student ID, and each response
    /// is imported as an attendance record for the currently-open event.
    private var checkInURL: String {
        "https://forms.office.com/r/mtM8pndeHf"
    }

    var body: some View {
        NavigationStack {
            GlassScene {
                ScrollView {
                    VStack(spacing: 22) {
                        qrImageView
                        captionBlock
                        liveCountChip
                        manualEntryCard
                    }
                    .padding(20)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Check-In QR")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    Button("Done") { dismiss() }
                        .tint(Theme.accent)
                }
            }
        }
    }

    // MARK: - Pieces

    private var qrImageView: some View {
        qrSwiftUIImage
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .padding(20)
            .frame(maxWidth: 320, maxHeight: 320)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Theme.accent.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: Theme.accent.opacity(0.15), radius: 18, x: 0, y: 6)
    }

    private var captionBlock: some View {
        VStack(spacing: 8) {
            Text("Students scan to open the SAO check-in form")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Link(destination: URL(string: checkInURL)!) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                    Text(checkInURL)
                }
                .font(.caption.monospaced())
                .foregroundStyle(Theme.accent)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal)
            }
            Text("Each form response is imported as the student's ID for this event.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var manualEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Import Form Response")
                .font(.headline)
            Text("Paste a student ID from a Microsoft Forms submission to add them to this event's attendance.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Student ID", text: $studentId)
                    .iosAutocap()
                    .autocorrectionDisabled()
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .softCard(radius: 12)
                    .submitLabel(.send)
                    .onSubmit(submit)

                Button("Check In", action: submit)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }

            if let feedback {
                Label(feedback.text,
                      systemImage: feedback.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(feedback.success ? Color.green : Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .glassCard(radius: 20)
    }

    private var liveCountChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.3.fill")
            Text("Live count: \(store.attendanceCount(for: eventId))")
                .font(.headline)
        }
        .foregroundStyle(Theme.accent)
        .padding(.vertical, 14)
        .padding(.horizontal, 22)
        .glassCard(tint: Theme.accent.opacity(0.32), radius: 24)
    }

    // MARK: - Helpers

    private struct FeedbackMessage {
        let text: String
        let success: Bool
    }

    private func submit() {
        let trimmed = studentId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            feedback = FeedbackMessage(text: "Enter a student ID first.",
                                       success: false)
            return
        }
        if store.recordAttendance(eventId: eventId, studentId: trimmed) {
            feedback  = FeedbackMessage(text: "Checked in \(trimmed)",
                                        success: true)
            studentId = ""
        } else {
            feedback  = FeedbackMessage(text: "\(trimmed) is already on the list.",
                                        success: false)
        }
    }

    private var qrSwiftUIImage: Image {
        filter.message         = Data(checkInURL.utf8)
        filter.correctionLevel = "M"
        guard
            let out = filter.outputImage?
                .transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
            let cg = context.createCGImage(out, from: out.extent)
        else {
            return Image(systemName: "xmark.octagon")
        }
        #if canImport(UIKit)
        return Image(uiImage: UIImage(cgImage: cg))
        #elseif canImport(AppKit)
        return Image(nsImage: NSImage(cgImage: cg,
                                      size: NSSize(width: cg.width,
                                                   height: cg.height)))
        #else
        return Image(systemName: "qrcode")
        #endif
    }
}

#Preview {
    QRCodeView(eventId: "e-7")
        .environmentObject(DataStore(clubsManager: ClubsDataManager()))
}
