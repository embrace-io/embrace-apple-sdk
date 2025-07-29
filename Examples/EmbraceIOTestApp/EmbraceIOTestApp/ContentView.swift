//
//  ContentView.swift
//  EmbraceIOTestApp
//
//

import EmbraceIO
import SwiftUI

struct ContentView: View {
    @Environment(DataCollector.self) private var dataCollector
    @State private var currentSelectedTest: TestMenuOptionDataModel = .embraceInit
    @State private var selected = TestMenuOptionDataModel.embraceInit.tag
    @State private var initialized: Bool = false
    @State private var displayTestMenu: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                TabView(selection: $selected) {
                    ForEach(TestMenuOptionDataModel.allCases, id: \.rawValue) {
                        $0.screen
                            .environment(dataCollector)
                            .tag($0.tag)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .offset(x: displayTestMenu ? 250 : 0, y: 0)
                .animation(.easeInOut, value: displayTestMenu)
                TestSideMenuView(isPresented: $displayTestMenu, selectedTestOption: $currentSelectedTest)
            }
            .navigationTitle(displayTestMenu ? "" : currentSelectedTest.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        displayTestMenu.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .tint(.embraceYellow)
                    }
                    .opacity(displayTestMenu ? 0 : 1.0)
                    .accessibilityIdentifier("SideMenuButton")
                }
            }
            .onChange(of: currentSelectedTest) {
                selected = currentSelectedTest.tag
            }
        }
    }
}

#Preview {
    let dataCollector = DataCollector()
    return NavigationView {
        ContentView()
            .environment(dataCollector)
    }
}
