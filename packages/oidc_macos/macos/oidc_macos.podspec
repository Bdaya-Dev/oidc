#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'oidc_macos'
  s.version          = '0.0.1'
  s.summary          = 'A macOS implementation of the oidc plugin.'
  s.description      = <<-DESC
  A macOS implementation of the oidc plugin.
                       DESC
  s.homepage         = 'https://bdaya-dev.github.io/oidc/'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Bdaya-Dev' => 'ahmednfwela@bdaya-dev.com' }
  s.source           = { :path => '.' }
  # SwiftPM-aligned layout (sources under <plugin_name>/Sources/<plugin_name>/).
  s.source_files = 'oidc_macos/Sources/oidc_macos/**/*.swift'
  s.dependency 'FlutterMacOS'

  s.platform = :osx
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.0'
end

