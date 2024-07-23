Pod::Spec.new do |spec|
  spec.name                           = "EmbraceIO-DEV"
  spec.version                        = "6.2.0-alpha"
  spec.summary                        = "Visibility into your users that you didn't have before."
  spec.description                    = <<-DESC
                      Embrace is the only performance monitoring platform focused solely on mobile. We are built
                      for the entire mobile team to assure the stability and performance of their apps.
                   DESC
  spec.homepage                       = "https://embrace.io"
  spec.documentation_url                 = "https://embrace.io/docs/"
  spec.license                        = { :type => "Apache 2.0" }
  spec.author                         = "Embrace.io"
  spec.source                         = { "http" => "https://github.com/embrace-io/embrace-apple-sdk/releases/download/#{spec.version}/embrace_#{spec.version}.zip" }
  spec.preserve_paths                 = [ "run.sh", "upload" ]
  spec.requires_arc                   = true
  spec.ios.deployment_target          = "13.0"
  spec.default_subspec = "EmbraceIO"

  spec.subspec 'EmbraceIO' do |io|
    io.vendored_frameworks = "xcframeworks/EmbraceIO.xcframework"
    io.dependency "EmbraceIO-DEV/EmbraceCaptureService"
    io.dependency "EmbraceIO-DEV/EmbraceCore"
    io.dependency "EmbraceIO-DEV/EmbraceCommonInternal"
    io.dependency "EmbraceIO-DEV/EmbraceCrash"
  end

  spec.subspec 'EmbraceCore' do |core|
    core.vendored_frameworks = "xcframeworks/EmbraceCore.xcframework"
    core.dependency "EmbraceIO-DEV/EmbraceCaptureService"
    core.dependency "EmbraceIO-DEV/EmbraceCommonInternal"
    core.dependency "EmbraceIO-DEV/EmbraceConfigInternal"
    core.dependency "EmbraceIO-DEV/EmbraceOTelInternal"
    core.dependency "EmbraceIO-DEV/EmbraceStorageInternal"
    core.dependency "EmbraceIO-DEV/EmbraceUploadInternal"
    core.dependency "EmbraceIO-DEV/EmbraceObjCUtilsInternal"
  end

  spec.subspec 'EmbraceCommonInternal' do |common|
    common.vendored_frameworks = "xcframeworks/EmbraceCommonInternal.xcframework"
  end

  spec.subspec 'EmbraceCaptureService' do |capture|
    capture.vendored_frameworks = "xcframeworks/EmbraceCaptureService.xcframework"
    capture.dependency "EmbraceIO-DEV/EmbraceOTelInternal"
    capture.dependency "EmbraceIO-DEV/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceConfigInternal' do |config|
    config.vendored_frameworks = "xcframeworks/EmbraceConfigInternal.xcframework"
    config.dependency "EmbraceIO-DEV/EmbraceCommonInternal"
  end

  spec.subspec 'EmbraceOTelInternal' do |otel|
    otel.vendored_frameworks = "xcframeworks/EmbraceOTelInternal.xcframework"
    otel.dependency "EmbraceIO-DEV/EmbraceCommonInternal"
    otel.dependency "EmbraceIO-DEV/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceStorageInternal' do |storage|
    storage.vendored_frameworks = "xcframeworks/EmbraceStorageInternal.xcframework"
    storage.dependency "EmbraceIO-DEV/EmbraceCommonInternal"
    storage.dependency "EmbraceIO-DEV/OpenTelemetryApi"
    storage.dependency "EmbraceIO-DEV/GRDB"
  end

  spec.subspec 'EmbraceUploadInternal' do |upload|
    upload.vendored_frameworks = "xcframeworks/EmbraceUploadInternal.xcframework"
    upload.dependency "EmbraceIO-DEV/EmbraceCommonInternal"
    upload.dependency "EmbraceIO-DEV/EmbraceOTelInternal"
    upload.dependency "EmbraceIO-DEV/GRDB"
  end

  spec.subspec 'EmbraceCrashlyticsSupport' do |cs|
    cs.vendored_frameworks = "xcframeworks/EmbraceCrashlyticsSupport.xcframework"
    cs.dependency "EmbraceIO-DEV/EmbraceCommonInternal"
  end

  spec.subspec 'EmbraceCrash' do |crash|
    crash.vendored_frameworks = "xcframeworks/EmbraceCrash.xcframework"
    crash.dependency "EmbraceIO-DEV/EmbraceCommonInternal"
    crash.dependency "EmbraceIO-DEV/KSCrash"
  end

  spec.subspec 'EmbraceObjCUtilsInternal' do |objc|
    objc.vendored_frameworks = "xcframeworks/EmbraceObjCUtilsInternal.xcframework"
  end

  # External
  spec.subspec 'OpenTelemetryApi' do |otelApi|
    otelApi.vendored_frameworks = "xcframeworks/OpenTelemetryApi.xcframework"
  end

  spec.subspec 'OpenTelemetrySdk' do |otelSdk|
    otelSdk.vendored_frameworks = "xcframeworks/OpenTelemetrySdk.xcframework"
    otelSdk.dependency "EmbraceIO-DEV/OpenTelemetryApi"
  end

  spec.subspec 'GRDB' do |grdb|
    grdb.vendored_frameworks = "xcframeworks/GRDB.xcframework"
  end

  spec.subspec 'KSCrash' do |kscrash|
    kscrash.dependency "EmbraceIO-DEV/KSCrashCore"
    kscrash.dependency "EmbraceIO-DEV/KSCrashRecording"
    kscrash.dependency "EmbraceIO-DEV/KSCrashRecordingCore"
  end

  spec.subspec 'KSCrashCore' do |kscrashCore|
    kscrashCore.vendored_frameworks = "xcframeworks/KSCrashCore.xcframework"
  end

  spec.subspec 'KSCrashRecording' do |kscrashRecording|
    kscrashRecording.vendored_frameworks = "xcframeworks/KSCrashRecording.xcframework"
    kscrashRecording.dependency "EmbraceIO-DEV/KSCrashRecordingCore"
  end

  spec.subspec 'KSCrashRecordingCore' do |kscrashRecordingCore|
    kscrashRecordingCore.vendored_frameworks = "xcframeworks/KSCrashRecordingCore.xcframework"
    kscrashRecordingCore.dependency "EmbraceIO-DEV/KSCrashCore"
  end
end
