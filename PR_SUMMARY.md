# Add Embrace Apple SDK - Complete Observability Solution for Apple Platforms

## Overview
This PR introduces the complete Embrace Apple SDK, a comprehensive observability and monitoring solution for iOS, iPadOS, tvOS, visionOS, and watchOS applications. This represents a major architectural shift from the previous Embrace SDK, adopting a modular approach with full OpenTelemetry standard support.

## Key Features Added

### 🔧 Core Observability Features
- **Session Management**: Complete session lifecycle tracking and management
- **Crash Reporting**: Comprehensive crash capture and reporting system
- **Network Monitoring**: Automatic network request/response capture and analysis
- **Performance Tracking**: OpenTelemetry trace capture and custom span creation
- **Memory Monitoring**: Low memory warning detection and app memory usage tracking
- **System Monitoring**: Low power mode detection and system state changes

### 📱 Platform-Specific Capabilities
- **UI Interaction Tracking**: Automatic tap and view capture (UIKit)
- **SwiftUI Support**: Dedicated instrumentation for SwiftUI applications
- **WebView Monitoring**: WebKit-based web view request tracking
- **Push Notification Tracking**: Push notification lifecycle monitoring

### 🔌 Integration & Export
- **OpenTelemetry Compatibility**: Full OTel standard compliance for interoperability
- **Custom Data Collection**: Support for custom logs, breadcrumbs, and user properties
- **Flexible Export**: Data can be sent to Embrace platform or any OTel Collector
- **Third-party Integration**: Built-in Crashlytics support and extensibility

## Technical Architecture

### 📦 Modular Design
- **EmbraceCore**: Foundation layer with core functionality
- **EmbraceIO**: Main SDK interface and orchestration
- **Specialized Modules**: Dedicated capture services for different data types
- **Storage Layer**: Efficient local data persistence with CoreData
- **Upload System**: Reliable data transmission with retry logic

### 🧪 Quality Assurance
- **Comprehensive Test Coverage**: 950+ files include extensive test suites
- **Multiple Example Apps**: Real-world usage examples and integration patterns
- **Performance Testing**: Dedicated performance benchmarking tools
- **CI/CD Pipeline**: Complete GitHub Actions workflows for testing and release

### 🛠 Developer Experience
- **Swift Package Manager**: Native SPM support with resolved dependencies
- **CocoaPods Support**: Traditional CocoaPods integration via podspec
- **Code Quality Tools**: Integrated SwiftLint, swift-format, and clang-format
- **Documentation**: Comprehensive getting started guides and API documentation

## Files Added
- **955 total files** with **82,540+ lines of code**
- Complete source code in `Sources/` directory
- Comprehensive test suites in `Tests/` directory
- Multiple example applications in `Examples/` directory
- CI/CD workflows and development tools
- Documentation and configuration files

## Breaking Changes
This is a new SDK implementation, representing a complete rewrite with:
- New API surface focused on OpenTelemetry standards
- Modular architecture allowing selective feature adoption
- Enhanced performance and reduced resource usage
- Modern Swift patterns and async/await support where appropriate

## Migration Impact
- Existing apps using previous Embrace SDK will need to migrate to new APIs
- New modular approach allows for more granular feature adoption
- OpenTelemetry compatibility enables integration with existing observability stacks
- Maintains core value proposition while improving extensibility

## Testing
- Unit tests for all core components and capture services
- Integration tests for end-to-end functionality
- Performance tests to ensure minimal app impact
- Platform-specific tests for iOS, tvOS, and watchOS
- Mock frameworks for reliable test execution

## Documentation
- Getting Started guide with step-by-step setup
- Comprehensive API documentation
- Example applications demonstrating key features
- Migration guides and best practices
- Contribution guidelines and code of conduct

---

This PR establishes the foundation for next-generation mobile observability on Apple platforms, providing developers with powerful insights while maintaining ease of integration and minimal performance impact.