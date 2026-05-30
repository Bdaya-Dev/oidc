#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'oidc_ios'
  s.version          = '0.0.1'
  s.summary          = 'An iOS implementation of the oidc plugin.'
  s.description      = <<-DESC
  An iOS implementation of the oidc plugin.
                       DESC
  s.homepage         = 'https://bdaya-dev.github.io/oidc/'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Bdaya-Dev' => 'ahmednfwela@bdaya-dev.com' }
  s.source           = { :path => '.' }
  # SwiftPM-aligned layout (sources under <plugin_name>/Sources/<plugin_name>/).
  s.source_files = 'oidc_ios/Sources/oidc_ios/**/*.swift'
  s.dependency 'Flutter'
  # ASWebAuthenticationSession + presentationContextProvider require iOS 13.
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
