Pod::Spec.new do |spec|
  spec.name                           = "EmbraceIO"
  spec.version                        = "6.8.4"
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
  spec.preserve_paths                 = [ "run.sh", "embrace_symbol_upload.darwin" ]
  spec.requires_arc                   = true
  spec.ios.deployment_target          = "13.0"
  spec.default_subspec = "EmbraceIO"

  spec.subspec 'EmbraceIO' do |io|
    io.dependency "EmbraceIO/EmbraceCaptureService"
    io.dependency "EmbraceIO/EmbraceCore"
    io.dependency "EmbraceIO/EmbraceCrash"
    io.dependency "EmbraceIO/EmbraceSemantics"
  end

  spec.subspec 'EmbraceCore' do |core|
    core.dependency "EmbraceIO/EmbraceCaptureService"
    core.dependency "EmbraceIO/EmbraceOTelInternal"
    core.dependency "EmbraceIO/EmbraceStorageInternal"
    core.dependency "EmbraceIO/EmbraceUploadInternal"
    core.dependency "EmbraceIO/EmbraceSemantics"
  end

  spec.subspec 'EmbraceSemantics' do |semantics|
    semantics.dependency "EmbraceIO/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceCaptureService' do |capture|
    capture.dependency "EmbraceIO/EmbraceOTelInternal"
    capture.dependency "EmbraceIO/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceOTelInternal' do |otel|
    otel.dependency "EmbraceIO/EmbraceSemantics"
    otel.dependency "EmbraceIO/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceStorageInternal' do |storage|
    storage.dependency "EmbraceIO/EmbraceSemantics"
    storage.dependency "EmbraceIO/GRDB"
  end

  spec.subspec 'EmbraceUploadInternal' do |upload|
    upload.dependency "EmbraceIO/EmbraceOTelInternal"
    upload.dependency "EmbraceIO/GRDB"
  end

  spec.subspec 'EmbraceCrash' do |crash|
    crash.dependency "KSCrash"
  end

  # External
  spec.subspec 'OpenTelemetrySdk' do |otelSdk|
    otelSdk.dependency "OpenTelemetry-Swift-Sdk"
  end

  spec.subspec 'GRDB' do |grdb|
    #grdb.vendored_frameworks = "xcframeworks/GRDB.xcframework"
    grdb.dependency "GRDB.swift"
  end
end
