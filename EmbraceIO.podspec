Pod::Spec.new do |spec|
  spec.name                           = "EmbraceIO"
  spec.version                        = "6.15.1"
  spec.summary                        = "Visibility into your users that you didn't have before."
  spec.description                    = <<-DESC
                      Embrace is the only performance monitoring platform focused solely on mobile. We are built
                      for the entire mobile team to assure the stability and performance of their apps.
                   DESC
  spec.homepage                       = "https://embrace.io"
  spec.documentation_url                 = "https://embrace.io/docs/"
  spec.license                        = { :type => "Apache 2.0" }
  spec.author                         = "Embrace.io"
  spec.source                         = { :git => "https://github.com/embrace-io/embrace-apple-sdk.git", :tag => spec.version }
  spec.requires_arc                   = true
  spec.ios.deployment_target          = "13.0"
  spec.swift_version                  = "5.9"
  spec.default_subspec = "EmbraceIO"

  ## Tell the Swift source code to not import subspecs as modules.
  spec.pod_target_xcconfig = {
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'EMBRACE_COCOAPOD_BUILDING_SDK',
    'OTHER_SWIFT_FLAGS' => '$(inherited) -package-name EmbraceIO'
  }

  spec.subspec 'EmbraceIO' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCaptureService"
    subs.dependency "EmbraceIO/EmbraceCore"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
    subs.dependency "EmbraceIO/EmbraceCrash"
    subs.dependency "EmbraceIO/EmbraceKSCrashBacktraceSupport"
    subs.dependency "EmbraceIO/EmbraceSemantics"
  end

  spec.subspec 'EmbraceCore' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCaptureService"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
    subs.dependency "EmbraceIO/EmbraceConfigInternal"
    subs.dependency "EmbraceIO/EmbraceOTelInternal"
    subs.dependency "EmbraceIO/EmbraceStorageInternal"
    subs.dependency "EmbraceIO/EmbraceUploadInternal"
    subs.dependency "EmbraceIO/EmbraceObjCUtilsInternal"
    subs.dependency "EmbraceIO/EmbraceSemantics"
    subs.dependency "EmbraceIO/EmbraceConfiguration"
  end

  spec.subspec 'EmbraceCommonInternal' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceAtomicsShim"
    subs.dependency "EmbraceIO/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceAtomicsShim' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.public_header_files = "Sources/#{subs.module_name}/include/**/*.h"
  end

  spec.subspec 'EmbraceSemantics' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
    subs.dependency "EmbraceIO/OpenTelemetrySdk"
  end

  spec.subspec 'EmbraceCaptureService' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceOTelInternal"
    subs.dependency "EmbraceIO/OpenTelemetrySdk"
    subs.dependency "EmbraceIO/EmbraceConfiguration"
  end

  spec.subspec 'EmbraceConfigInternal' do |subs|
   subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
   subs.dependency "EmbraceIO/EmbraceCommonInternal"
   subs.dependency "EmbraceIO/EmbraceConfiguration"
  end

  spec.subspec 'EmbraceConfiguration' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
  end

  spec.subspec 'EmbraceOTelInternal' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
    subs.dependency "EmbraceIO/EmbraceSemantics"
    subs.dependency "EmbraceIO/OpenTelemetrySdk"
    subs.dependency "EmbraceIO/EmbraceCoreDataInternal"
    subs.dependency "EmbraceIO/EmbraceStorageInternal"
  end

  spec.subspec 'EmbraceStorageInternal' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
    subs.dependency "EmbraceIO/EmbraceSemantics"
    subs.dependency "EmbraceIO/EmbraceCoreDataInternal"
  end

  spec.subspec 'EmbraceCoreDataInternal' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
    subs.dependency "EmbraceIO/EmbraceObjCUtilsInternal"
  end

  spec.subspec 'EmbraceUploadInternal' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
    subs.dependency "EmbraceIO/EmbraceCoreDataInternal"
    subs.dependency "EmbraceIO/EmbraceOTelInternal"
  end

  spec.subspec 'EmbraceCrashlyticsSupport' do |subs|
    subs.source_files = "Sources/ThirdParty/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
  end

  spec.subspec 'EmbraceCrash' do |subs|
    subs.source_files = "Sources/ThirdParty/EmbraceKSCrashSupport/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
    subs.dependency "EmbraceIO/EmbraceSemantics"
    subs.dependency "EmbraceIO/EmbraceKSCrash"
  end

  spec.subspec 'EmbraceKSCrashBacktraceSupport' do |subs|
    subs.source_files = "Sources/ThirdParty/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
    subs.dependency "EmbraceIO/EmbraceCommonInternal"
    subs.dependency "EmbraceIO/EmbraceKSCrash"
  end

  spec.subspec 'EmbraceObjCUtilsInternal' do |subs|
    subs.source_files = "Sources/#{subs.module_name}/**/*.{h,m,mm,c,cpp,swift}"
  end

  # External
  spec.subspec 'EmbraceKSCrash' do |subs|
    subs.dependency "KSCrash", "~> 2.4"
  end

  spec.subspec 'OpenTelemetrySdk' do |subs|
    subs.dependency "OpenTelemetry-Swift-Sdk", "~> 2.1"
  end
end
