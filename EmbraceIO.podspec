Pod::Spec.new do |spec|
  spec.name                           = "EmbraceIO"
  spec.version                        = "6.0.0"
  spec.summary                        = "Visibility into your users that you didn't have before."
  spec.description                    = <<-DESC
                      Embrace is the only performance monitoring platform focused solely on mobile. We are built
                      for the entire mobile team to assure the stability and performance of their apps.
                   DESC
  spec.homepage                       = "https://embrace.io"
  spec.documentation_url                 = "https://embrace.io/docs/"
  spec.license                        = { :type => "Apache 2.0" }
  spec.author                         = "Embrace.io"
  spec.source                         = { "http" => "https://embrace-downloads-prod.s3.amazonaws.com/embrace_#{spec.version}.zip" }
  spec.preserve_paths                 = [ "run.sh", "upload" ]
  spec.requires_arc                   = true
  spec.ios.deployment_target          = "13.0"
  spec.default_subspec = "EmbraceIO"

  spec.subspec 'EmbraceIO' do |io|
    io.vendored_frameworks = "xcframeworks/EmbraceIO.xcframework"
    io.dependency "EmbraceIO/EmbraceCaptureService"
    io.dependency "EmbraceIO/EmbraceCore"
    io.dependency "EmbraceIO/EmbraceCommonInternal"
    io.dependency "EmbraceIO/EmbraceCrash"
  end

  spec.subspec 'EmbraceCore' do |core|
    core.vendored_frameworks = "xcframeworks/EmbraceCore.xcframework"
    core.dependency "EmbraceIO/EmbraceCaptureService"
    core.dependency "EmbraceIO/EmbraceCommonInternal"
    core.dependency "EmbraceIO/EmbraceConfigInternal"
    core.dependency "EmbraceIO/EmbraceOTelInternal"
    core.dependency "EmbraceIO/EmbraceStorageInternal"
    core.dependency "EmbraceIO/EmbraceUploadInternal"
    core.dependency "EmbraceIO/EmbraceObjCUtilsInternal"
  end

  spec.subspec 'EmbraceCommonInternal' do |common|
    common.vendored_frameworks = "xcframeworks/EmbraceCommonInternal.xcframework"
  end

  spec.subspec 'EmbraceCaptureService' do |capture|
    capture.vendored_frameworks = "xcframeworks/EmbraceCaptureService.xcframework"
    capture.dependency "EmbraceIO/EmbraceOTelInternal"
    capture.dependency "EmbraceIO/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceConfigInternal' do |config|
    config.vendored_frameworks = "xcframeworks/EmbraceConfigInternal.xcframework"
    config.dependency "EmbraceIO/EmbraceCommonInternal"
  end

  spec.subspec 'EmbraceOTelInternal' do |otel|
    otel.vendored_frameworks = "xcframeworks/EmbraceOTelInternal.xcframework"
    otel.dependency "EmbraceIO/EmbraceCommonInternal"
    otel.dependency "EmbraceIO/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceStorageInternal' do |storage|
    storage.vendored_frameworks = "xcframeworks/EmbraceStorageInternal.xcframework"
    storage.dependency "EmbraceIO/EmbraceCommonInternal"
    storage.dependency "EmbraceIO/OpenTelemetryApi"
    storage.dependency "EmbraceIO/GRDB"
  end

  spec.subspec 'EmbraceUploadInternal' do |upload|
    upload.vendored_frameworks = "xcframeworks/EmbraceUploadInternal.xcframework"
    upload.dependency "EmbraceIO/EmbraceCommonInternal"
    upload.dependency "EmbraceIO/EmbraceOTelInternal"
    upload.dependency "EmbraceIO/GRDB"
  end

  spec.subspec 'EmbraceCrashlyticsSupport' do |cs|
    cs.vendored_frameworks = "xcframeworks/EmbraceCrashlyticsSupport.xcframework"
    cs.dependency "EmbraceIO/EmbraceCommonInternal"
  end

  spec.subspec 'EmbraceCrash' do |crash|
    crash.vendored_frameworks = "xcframeworks/EmbraceCrash.xcframework"
    crash.dependency "EmbraceIO/EmbraceCommonInternal"
    crash.dependency "EmbraceIO/KSCrash"
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
    otelSdk.dependency "EmbraceIO/OpenTelemetryApi"
  end

  spec.subspec 'GRDB' do |grdb|
    grdb.vendored_frameworks = "xcframeworks/GRDB.xcframework"
  end

  spec.subspec 'KSCrash' do |kscrash|
    kscrash.dependency "EmbraceIO/KSCrashCore"
    kscrash.dependency "EmbraceIO/KSCrashRecording"
    kscrash.dependency "EmbraceIO/KSCrashRecordingCore"
  end

  spec.subspec 'KSCrashCore' do |kscrashCore|
    kscrashCore.vendored_frameworks = "xcframeworks/KSCrashCore.xcframework"
  end

  spec.subspec 'KSCrashRecording' do |kscrashRecording|
    kscrashRecording.vendored_frameworks = "xcframeworks/KSCrashRecording.xcframework"
    kscrashRecording.dependency "EmbraceIO/KSCrashRecordingCore"
  end

  spec.subspec 'KSCrashRecordingCore' do |kscrashRecordingCore|
    kscrashRecordingCore.vendored_frameworks = "xcframeworks/KSCrashRecordingCore.xcframework"
    kscrashRecordingCore.dependency "EmbraceIO/KSCrashCore"
  end
end
