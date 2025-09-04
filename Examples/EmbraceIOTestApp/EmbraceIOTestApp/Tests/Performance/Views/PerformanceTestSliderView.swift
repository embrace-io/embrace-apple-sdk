//
//  PerformanceTestSliderView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct PerformanceTestSliderView: View {
    @State var title: String
    @State var maxValue: Double
    @Binding var value: Double
    var body: some View {
        VStack {
            Text("\(title): \(UInt32(value))")
                .textCase(nil)
                .font(.embraceFont(size: 15))
                .foregroundStyle(.embraceSilver)
            Slider(value: $value, in: 1...maxValue, step: 1) {
            } minimumValueLabel: {
                Text("1")
                    .textCase(nil)
                    .font(.embraceFont(size: 12))
                    .foregroundStyle(.embraceSilver)
            } maximumValueLabel: {
                Text("\(UInt32(maxValue))")
                    .textCase(nil)
                    .font(.embraceFont(size: 12))
                    .foregroundStyle(.embraceSilver)
            }
            .tint(.embracePurple)
        }
        .padding([.leading, .trailing], 20)
    }
}
