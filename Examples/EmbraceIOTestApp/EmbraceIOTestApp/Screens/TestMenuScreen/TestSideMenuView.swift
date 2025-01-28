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
                    List(TestMenuOptionDataModel.allCases, id: \.rawValue, selection: $selectedOption) {
                        Text($0.title)
                            .font(.embraceFont(size: 15))
                            .foregroundStyle(.embraceSilver)
                            .listRowBackground($0.rawValue == selectedOption ? Color.embracePurple : Color.embraceLead)
                            .accessibilityIdentifier($0.identifier)
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
    @Previewable @State var isPresented = true
    @Previewable @State var selectedOption: TestMenuOptionDataModel = .embraceInit
    TestSideMenuView(isPresented: $isPresented, selectedTestOption: $selectedOption)
}
