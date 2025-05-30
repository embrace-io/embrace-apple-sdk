//
//  TestReportCardSectionsView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestReportCardSectionsView: View {
    var body: some View {
        VStack{
            HStack {
                Text("Target")
                    .font(.embraceFont(size: 12))
                    .frame(width: 100, alignment: .leading)
                Text("Expected")
                    .font(.embraceFont(size: 12))
                    .frame(width: 100, alignment: .leading)
                Text("Recorded")
                    .font(.embraceFont(size: 12))
                    .frame(width: 100, alignment: .leading)
                Spacer()
            }
        }
    }
}

#Preview {
    return TestReportCardSectionsView()
}
