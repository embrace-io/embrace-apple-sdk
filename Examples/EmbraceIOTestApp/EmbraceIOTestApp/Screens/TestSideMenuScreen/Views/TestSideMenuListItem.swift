
//
//  TestSideMenuListItem.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestSideMenuListItem: View {
    var item: TestMenuOptionDataModel
    var selected: Bool
    var body: some View {
        Text(item.title)
            .font(.embraceFont(size: 15))
            .foregroundStyle(.embraceSilver)
            .listRowBackground(selected ? Color.embracePurple : Color.embraceLead)
            .accessibilityIdentifier(item.identifier)
    }
}

#Preview {
    @State var selectedOption: Int? = nil
    return List(TestMenuOptionDataModel.allCases, id: \.rawValue, selection: $selectedOption) { item in
        TestSideMenuListItem(item: item, selected: item.rawValue == selectedOption)
    }
}
