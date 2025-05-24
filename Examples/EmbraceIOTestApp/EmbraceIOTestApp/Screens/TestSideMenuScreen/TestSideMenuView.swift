//
//  TestSideMenuView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI

struct TestSideMenuView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTestOption: TestMenuOptionDataModel
    @State private var selectedOption: Int? = nil
    var body: some View {
        ZStack {
            Rectangle()
                .ignoresSafeArea()
                .opacity(isPresented ? 0.6 : 0)
                .onTapGesture {
                    isPresented.toggle()
                }
                .ignoresSafeArea()
            HStack {
                VStack(alignment: .center, spacing: 30) {
                    TestMenuHeaderView()
                    List(TestMenuOptionDataModel.allCases, id: \.rawValue, selection: $selectedOption) { item in
                        TestSideMenuListItem(item: item, selected: item.rawValue == selectedOption)
                    }
                    .listStyle(.plain)
                    .background(.embraceLead)
                    Spacer()
                }
                .padding()
                .frame(width: 250)
                .background(.embraceLead)
                Spacer()
            }
            .offset(x: isPresented ? 0 : -250, y: 0)
        }
        .animation(.easeInOut, value: isPresented)
        .onChange(of: selectedOption) {
            guard let rawValue = selectedOption else { return }
            selectedTestOption = TestMenuOptionDataModel(rawValue: rawValue) ?? .embraceInit
            isPresented.toggle()
        }
    }
}

#Preview {
    @State var isPresented = true
    @State var selectedOption: TestMenuOptionDataModel = .embraceInit
    return TestSideMenuView(isPresented: $isPresented, selectedTestOption: $selectedOption)
}
