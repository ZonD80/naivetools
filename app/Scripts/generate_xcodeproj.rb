#!/usr/bin/env ruby

require "fileutils"
require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "NaiveVPN.xcodeproj")

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastUpgradeCheck"] = "2600"
project.root_object.attributes["LastSwiftUpdateCheck"] = "2600"

main_group = project.main_group
app_group = main_group.new_group("NaiveVPN", "NaiveVPN")
extension_group = main_group.new_group("NaiveTunnelExtension", "NaiveTunnelExtension")
shared_group = main_group.new_group("Shared", "Shared")
scripts_group = main_group.new_group("Scripts", "Scripts")

frameworks_group = project.frameworks_group || main_group.new_group("Frameworks")
libbox_ref = frameworks_group.new_file("Libbox.xcframework")

scripts_group.new_file("build_libbox.sh")
scripts_group.new_file("libbox_flatten_framework.sh")
scripts_group.new_file("flatten_libbox_xcframework.sh")
scripts_group.new_file("generate_xcodeproj.rb")

app_target = project.new_target(:application, "NaiveVPN", :ios, "17.0")
extension_target = project.new_target(:app_extension, "NaiveTunnelExtension", :ios, "17.0")

def configure_project_settings(project)
  common = {
    "BASE_PACKAGE_IDENTIFIER" => "com.example.naivevpn",
    "CODE_SIGN_STYLE" => "Automatic",
    "CURRENT_PROJECT_VERSION" => "1",
    "DEVELOPMENT_TEAM" => "",
    "IPHONEOS_DEPLOYMENT_TARGET" => "17.0",
    "MARKETING_VERSION" => "1.0",
    "SWIFT_VERSION" => "5.0",
    "TARGETED_DEVICE_FAMILY" => "1,2",
  }

  project.build_configurations.each do |config|
    config.build_settings.merge!(common)
  end
end

def configure_app_target(target)
  target.build_configurations.each do |config|
    config.build_settings.merge!(
      "ASSETCATALOG_COMPILER_APPICON_NAME" => "AppIcon",
      "CODE_SIGN_ENTITLEMENTS" => "NaiveVPN/NaiveVPN.entitlements",
      "GENERATE_INFOPLIST_FILE" => "NO",
      "INFOPLIST_FILE" => "NaiveVPN/Info.plist",
      "LD_RUNPATH_SEARCH_PATHS" => "$(inherited) @executable_path/Frameworks",
      "PRODUCT_BUNDLE_IDENTIFIER" => "$(BASE_PACKAGE_IDENTIFIER)",
      "PRODUCT_NAME" => "NaiveVPN",
      "SUPPORTED_PLATFORMS" => "iphoneos iphonesimulator",
      "SWIFT_EMIT_LOC_STRINGS" => "NO"
    )
  end
end

def configure_extension_target(target)
  target.build_configurations.each do |config|
    config.build_settings.merge!(
      "APPLICATION_EXTENSION_API_ONLY" => "YES",
      "CODE_SIGN_ENTITLEMENTS" => "NaiveTunnelExtension/NaiveTunnelExtension.entitlements",
      "GENERATE_INFOPLIST_FILE" => "NO",
      "INFOPLIST_FILE" => "NaiveTunnelExtension/Info.plist",
      "LD_RUNPATH_SEARCH_PATHS" => "$(inherited) @executable_path/../../Frameworks",
      "PRODUCT_BUNDLE_IDENTIFIER" => "$(BASE_PACKAGE_IDENTIFIER).extension",
      "PRODUCT_NAME" => "NaiveTunnelExtension",
      "SKIP_INSTALL" => "YES",
      "SUPPORTED_PLATFORMS" => "iphoneos iphonesimulator"
    )
  end
end

configure_project_settings(project)
configure_app_target(app_target)
configure_extension_target(extension_target)

app_files = %w[
  NaiveVPNApp.swift
  ContentView.swift
  ConnectionStore.swift
  ShareProfileSheet.swift
  AppdbVersionUpdateChecker.swift
]

shared_files = %w[
  AppConfiguration.swift
  Logger+Extension.swift
  AsyncNetworkExtension.swift
  NaiveServerProfile.swift
  NaiveProfileStore.swift
  NaiveConfigBuilder.swift
]

extension_files = %w[
  PacketTunnelProvider.swift
  Extension+Iterator.swift
  Extension+RunBlocking.swift
  ExtensionErrors.swift
  ExtensionStartOptions.swift
  ExtensionProvider.swift
  ExtensionPlatformInterface.swift
]

app_files.each do |path|
  ref = app_group.new_file(path)
  app_target.add_file_references([ref])
end

shared_files.each do |path|
  ref = shared_group.new_file(path)
  app_target.add_file_references([ref])
  extension_target.add_file_references([ref])
end

extension_files.each do |path|
  ref = extension_group.new_file(path)
  extension_target.add_file_references([ref])
end

assets_ref = app_group.new_file("Assets.xcassets")
app_target.resources_build_phase.add_file_reference(assets_ref)
app_group.new_file("Info.plist")
app_group.new_file("NaiveVPN.entitlements")
extension_group.new_file("Info.plist")
extension_group.new_file("NaiveTunnelExtension.entitlements")

extension_target.frameworks_build_phase.add_file_reference(libbox_ref)

app_target.add_dependency(extension_target)
embed_frameworks = app_target.new_copy_files_build_phase("Embed Frameworks")
embed_frameworks.symbol_dst_subfolder_spec = :frameworks if embed_frameworks.respond_to?(:symbol_dst_subfolder_spec=)
embed_frameworks.dst_subfolder_spec = "10"
embedded_framework = embed_frameworks.add_file_reference(libbox_ref, true)
embedded_framework.settings = { "ATTRIBUTES" => ["CodeSignOnCopy", "RemoveHeadersOnCopy"] }
embed_extensions = app_target.new_copy_files_build_phase("Embed App Extensions")
embed_extensions.dst_subfolder_spec = "13"
embedded_extension = embed_extensions.add_file_reference(extension_target.product_reference, true)
embedded_extension.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

project.save

puts "Generated #{PROJECT_PATH}"
