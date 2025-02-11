//
//  ContentView.swift
//  EmbraceIOTestApp
//
//

import SwiftUI
import EmbraceIO

import OpenTelemetrySdk

struct ContentView: View {
    @Environment(TestSpanExporter.self) private var spanExporter
    @Environment(TestLogRecordExporter.self) private var logExporter
    @State private var currentSelectedTest: TestMenuOptionDataModel = .embraceInit
    @State private var selected = TestMenuOptionDataModel.embraceInit.tag
    @State private var initialized: Bool = false
    @State private var displayTestMenu: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                TabView(selection: $selected) {
                    ForEach(TestMenuOptionDataModel.allCases, id:\.rawValue) {
                        $0.screen
                            .environment(spanExporter)
                            .environment(logExporter)
                            .tag($0.tag)
                    }
                }
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
    let spanExporter = TestSpanExporter()
    let logExporter = TestLogRecordExporter()
    NavigationView {
        ContentView()
            .environment(spanExporter)
            .environment(logExporter)
    }
}
