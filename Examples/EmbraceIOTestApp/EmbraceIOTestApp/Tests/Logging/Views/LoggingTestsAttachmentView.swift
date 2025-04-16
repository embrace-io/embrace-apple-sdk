//
//  LoggingTestsAttachmentView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct LoggingTestsAttachmentView: View {
    @Binding var addAttachment: Bool
    @Binding var attachmentSize: Float
    ///This is a controlled test app. Make sure hardcoded file sizes are powers of 2.
    ///If values here are tweaked, please update the UI Test app to set the correct normalized slider position to match the max file size.
    private var step: Float { 8192 }
    private var maxAllowedSize: Float { 1048576 }
    private var maxSize: Float { step * 150 }
    var body: some View {
        VStack {
            Toggle("Include Attachment", isOn: $addAttachment)
                .tint(.embracePurple)
                .padding([.leading, .trailing, .bottom], 5)
                .accessibilityIdentifier("attachmentToggle")
            Text("Attachment size: \(formattedSize(UInt32(attachmentSize)))")
                .foregroundStyle(attachmentSize > maxAllowedSize ? .embracePink : .embraceSteel)
            Slider(value: $attachmentSize, in: step...maxSize, step: step) {

            }
            minimumValueLabel: {
                Text("8KB")
            } maximumValueLabel: {
                Text("1.17 MB")
            }
            .tint(.embracePurple)
            .accessibilityIdentifier("attachmentSizeSlider")
            Text("Max allowed size: 1MB")
        }
    }

    private func kilobytes(_ bytes: UInt32) -> Float {
        return Float(bytes / 1024)
    }

    private func megabytes(_ bytes: UInt32) -> Float {
        return kilobytes(bytes) / 1024
    }

    /// This is very rough but since we're only counting KB and MB, we don't need to do anything fancy.
    /// Bytes is only there for completion's sake, but we're not gonna be using it.
    private func formattedSize(_ bytes: UInt32) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        }

        if bytes < 1048576 {
            return "\(String(format: "%.0f", kilobytes(bytes))) KB"
        }

        return "\(String(format: "%.2f", megabytes(bytes))) MB"
    }
}

#Preview {
    @Previewable @State var addAttachment: Bool = false
    @Previewable @State var attachmentSize: Float = 8192
    LoggingTestsAttachmentView(addAttachment: $addAttachment, attachmentSize: $attachmentSize)
}
