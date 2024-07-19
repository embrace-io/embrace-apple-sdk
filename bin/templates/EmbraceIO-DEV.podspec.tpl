Pod::Spec.new do |spec|
  spec.name                           = "EmbraceIO-DEV"
  spec.version                        = "__REPLACE_VERSION__"
  spec.summary                        = "Visibility into your users that you didn't have before."
  spec.description                    = <<-DESC
                      Embrace is the only performance monitoring platform focused solely on mobile. We are built
                      for the entire mobile team to assure the stability and performance of their apps.
                   DESC
  spec.homepage                       = "https://embrace.io"
  spec.documentation_url                 = "https://embrace.io/docs/"
  spec.license                        = { :type => "Apache 2.0" }
  spec.author                         = "Embrace.io"
  spec.source                         = { "http" => "https://downloads.stg.emb-eng.com/embrace_#{spec.version}.zip" }
  spec.preserve_paths                 = [ "run.sh", "upload" ]
  spec.requires_arc                   = true
  spec.ios.deployment_target          = "13.0"
  spec.default_subspec = "EmbraceIO"

  spec.subspec 'EmbraceIO' do |io|
    io.vendored_frameworks = "xcframeworks/EmbraceIO.xcframework"
    io.dependency "EmbraceIO-DEV/EmbraceCaptureService"
    io.dependency "EmbraceIO-DEV/EmbraceCore"
    io.dependency "EmbraceIO-DEV/EmbraceCommon"
    io.dependency "EmbraceIO-DEV/EmbraceCrash"
  end

  spec.subspec 'EmbraceCore' do |core|
    core.vendored_frameworks = "xcframeworks/EmbraceCore.xcframework"
    core.dependency "EmbraceIO-DEV/EmbraceCaptureService"
    core.dependency "EmbraceIO-DEV/EmbraceCommon"
    core.dependency "EmbraceIO-DEV/EmbraceConfig"
    core.dependency "EmbraceIO-DEV/EmbraceOTel"
    core.dependency "EmbraceIO-DEV/EmbraceStorage"
    core.dependency "EmbraceIO-DEV/EmbraceUpload"
    core.dependency "EmbraceIO-DEV/EmbraceObjCUtils"
  end

  spec.subspec 'EmbraceCommon' do |common|
    common.vendored_frameworks = "xcframeworks/EmbraceCommon.xcframework"
  end

  spec.subspec 'EmbraceCaptureService' do |capture|
    capture.vendored_frameworks = "xcframeworks/EmbraceCaptureService.xcframework"
    capture.dependency "EmbraceIO-DEV/EmbraceOTel"
    capture.dependency "EmbraceIO-DEV/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceConfig' do |config|
    config.vendored_frameworks = "xcframeworks/EmbraceConfig.xcframework"
    config.dependency "EmbraceIO-DEV/EmbraceCommon"
  end

  spec.subspec 'EmbraceOTel' do |otel|
    otel.vendored_frameworks = "xcframeworks/EmbraceOTel.xcframework"
    otel.dependency "EmbraceIO-DEV/EmbraceCommon"
    otel.dependency "EmbraceIO-DEV/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceStorage' do |storage|
    storage.vendored_frameworks = "xcframeworks/EmbraceStorage.xcframework"
    storage.dependency "EmbraceIO-DEV/EmbraceCommon"
    storage.dependency "EmbraceIO-DEV/OpenTelemetryApi"
    storage.dependency "EmbraceIO-DEV/GRDB"
  end

  spec.subspec 'EmbraceUpload' do |upload|
    upload.vendored_frameworks = "xcframeworks/EmbraceUpload.xcframework"
    upload.dependency "EmbraceIO-DEV/EmbraceCommon"
    upload.dependency "EmbraceIO-DEV/EmbraceOTel"
    upload.dependency "EmbraceIO-DEV/GRDB"
  end

  spec.subspec 'EmbraceCrashlyticsSupport' do |cs|
    cs.vendored_frameworks = "xcframeworks/EmbraceCrashlyticsSupport.xcframework"
    cs.dependency "EmbraceIO-DEV/EmbraceCommon"
  end

  spec.subspec 'EmbraceCrash' do |crash|
    crash.vendored_frameworks = "xcframeworks/EmbraceCrash.xcframework"
    crash.dependency "EmbraceIO-DEV/EmbraceCommon"
    crash.dependency "EmbraceIO-DEV/KSCrash"
  end

  spec.subspec 'EmbraceObjCUtils' do |objc|
    objc.vendored_frameworks = "xcframeworks/EmbraceObjCUtils.xcframework"
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
