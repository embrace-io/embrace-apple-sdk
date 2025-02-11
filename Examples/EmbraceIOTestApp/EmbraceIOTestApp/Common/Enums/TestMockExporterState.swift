//
//  TestMockExporterState.swift
//  EmbraceIOTestApp
//
//

/// `waiting`: The Span Exporter has not yet received any payloads.
/// `ready`: One or more spans have been exported and are ready to be tested
/// `testing`: Tests are currently being performed
/// `clear`: All previous cached spans have been cleared out so there's nothing to test.
enum TestMockExporterState {
    case waiting
    case ready
    case testing
    case clear
}
