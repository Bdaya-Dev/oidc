#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'oidc_darwin'
  s.version          = '0.0.1'
  s.summary          = 'iOS and macOS implementation of the oidc plugin.'
  s.description      = <<-DESC
  iOS and macOS implementation of the oidc plugin (ASWebAuthenticationSession).
                       DESC
  s.homepage         = 'https://bdaya-dev.github.io/oidc/'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Bdaya-Dev' => 'ahmednfwela@bdaya-dev.com' }
  s.source           = { :path => '.' }
  # SwiftPM-aligned layout (sources under <plugin_name>/Sources/<plugin_name>/).
  s.source_files = 'oidc_darwin/Sources/oidc_darwin/**/*.swift'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  # ASWebAuthenticationSession + presentationContextProvider require iOS 13.
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  # Flutter.framework does not contain an i386 slice (the EXCLUDED_ARCHS entry is
  # sdk-scoped to the iOS simulator, so it is inert on the macOS build).
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
