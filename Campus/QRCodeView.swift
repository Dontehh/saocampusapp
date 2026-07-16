//
//  QRCodeView.swift
//  Campus
//
//  Refined check-in sheet. Editorial header, generous whitespace, single
//  accent card for the QR frame. Manual response import stays as a
//  simple hairline card at the bottom.
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

    @State private var studentId = ""
    @State private var feedback:  FeedbackMessage?

    private let context = CIContext()
    private let filter  = CIFilter.qrCodeGenerator()

    /// Shared SAO check-in form. Every event's QR encodes this URL.
    private var checkInURL: String {
        "https://forms.office.com/r/mtM8pndeHf"
    }

    var body: some View {
        NavigationStack {
            GlassScene {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                        header
                        qrCard
                        liveCountCard
                        importCard
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                    .contentFrame(max: AppLayout.readingMaxWidth)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    Button("Done") { dismiss() }
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Check-in").overlineStyle(Theme.accent)
            Text("Attendance QR")
                .font(AppFont.title)
                .foregroundStyle(Theme.ink)
            Text("Students scan to open the SAO form. Each submission is imported as an attendance record for this event.")
                .font(AppFont.caption)
                .foregroundStyle(Theme.inkMuted)
        }
    }

    private var qrCard: some View {
        VStack(spacing: 16) {
            qrSwiftUIImage
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(20)
                .frame(maxWidth: 300, maxHeight: 300)
                .background(Color.white,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.rule, lineWidth: AppLayout.hairline)
                )

            Link(destination: URL(string: checkInURL)!) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .medium))
                    Text(checkInURL)
                        .font(AppFont.mono)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .surfaceCard()
    }

    private var liveCountCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Live count").overlineStyle(Theme.accent)
                Text("\(store.attendanceCount(for: eventId))")
                    .font(AppFont.displayNumber)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("students checked in")
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer()
        }
        .padding(20)
        .heroCard()
        .animation(AppMotion.smooth, value: store.attendanceCount(for: eventId))
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import response").overlineStyle()
            Text("Paste a student ID from a submitted form and add them to this event's attendance.")
                .font(AppFont.caption)
                .foregroundStyle(Theme.inkMuted)

            HStack(spacing: 10) {
                TextField("Student ID", text: $studentId)
                    .iosAutocap()
                    .autocorrectionDisabled()
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Theme.fill,
                                in: RoundedRectangle(cornerRadius: 12,
                                                     style: .continuous))
                    .submitLabel(.send)
                    .onSubmit(submit)
                Button("Check In", action: submit)
                    .font(AppFont.bodyEmphasis)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.accent,
                                in: RoundedRectangle(cornerRadius: 12,
                                                     style: .continuous))
            }

            if let f = feedback {
                HStack(spacing: 6) {
                    Image(systemName: f.success ? "checkmark.circle.fill"
                                                : "xmark.octagon.fill")
                    Text(f.text)
                }
                .font(AppFont.captionStrong)
                .foregroundStyle(f.success ? Theme.positive : Theme.negative)
                .transition(.opacity)
            }
        }
        .padding(18)
        .surfaceCard()
    }

    // MARK: - Logic

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
