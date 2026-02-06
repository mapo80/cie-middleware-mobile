# frozen_string_literal: true
require 'pathname'

plugin_ios_dir = File.realpath(__dir__)
sdk_root = File.expand_path('../../cie_sign_sdk', plugin_ios_dir)
ios_sdk_root = File.expand_path('../../cie_sign_ios_sdk', plugin_ios_dir)

# Auto-detect best vcpkg triplet (prefer arm64-ios-17 if it has cryptopp)
vcpkg_installed = File.join(sdk_root, '.vcpkg/installed')
vcpkg_triplet = 'arm64-ios-17'
vcpkg_triplet = 'arm64-ios' unless File.exist?(File.join(vcpkg_installed, vcpkg_triplet, 'lib/libcryptopp.a'))

vcpkg_device_lib = File.join(vcpkg_installed, vcpkg_triplet, 'lib')
vcpkg_sim_triplet = 'arm64-ios-simulator'
vcpkg_sim_lib = File.join(vcpkg_installed, vcpkg_sim_triplet, 'lib')

device_lib_paths = [
  File.join(sdk_root, 'build/ios'),
  File.join(sdk_root, 'build/ios/Debug-iphoneos'),
  File.join(sdk_root, 'build/ios/Release-iphoneos'),
  vcpkg_device_lib
]

sim_lib_paths = [
  File.join(sdk_root, 'build/ios-sim'),
  File.join(sdk_root, 'build/ios-sim/Release-iphonesimulator'),
  File.join(sdk_root, 'build/ios-sim/Debug-iphonesimulator'),
  vcpkg_sim_lib
]

# Force-load podofo, fmt, and freetype libraries
force_load_libs = %w[libpodofo.a libpodofo_private.a libpodofo_3rdparty.a libfmt.a libfreetype.a libfontconfig.a]
podofo_force_load_device = force_load_libs.map { |lib| "-force_load #{File.join(vcpkg_device_lib, lib)}" }.join(' ')
podofo_force_load_sim = force_load_libs.map { |lib| "-force_load #{File.join(vcpkg_sim_lib, lib)}" }.join(' ')

# Common link flags (without force-loaded libraries)
common_link_flags = %W[
  -ObjC
  -lciesign_core
  -lcie_sign_sdk
  -lcrypto
  -lssl
  -lcurl
  -lxml2
  -lz
  -lpng16
  -lbz2
  -lbrotlienc
  -lbrotlidec
  -lbrotlicommon
  -ljpeg
  -lturbojpeg
  -ltiff
  -llzma
  -lutf8proc
  -lexpat
  -lcryptopp
  -liconv
  -lcharset
  -ldate-tz
  -lc++
  -lc++abi
].join(' ')

device_link_flags = "$(inherited) #{common_link_flags} #{podofo_force_load_device}"
sim_link_flags = "$(inherited) #{common_link_flags} #{podofo_force_load_sim}"

header_paths = [
  File.join(sdk_root, 'include'),
  File.join(sdk_root, 'src'),
  File.join(sdk_root, 'tests'),
  File.join(sdk_root, 'tests/mock')
].join(' ')

# Compute relative paths for source_files (CocoaPods requires relative paths)
plugin_to_ios_sdk = Pathname.new(ios_sdk_root).relative_path_from(Pathname.new(plugin_ios_dir))

Pod::Spec.new do |s|
  s.name             = 'cie_sign_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter bindings for the CIE signing core.'
  s.description      = 'Internal plugin exposing the CIE signing SDK to Flutter.'
  s.homepage         = 'https://github.com/italia/cie-middleware'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'IPZS' => 'info@ipzs.it' }
  s.source           = { :http => 'https://github.com/italia/cie-middleware/archive/master.zip' }
  s.source_files     = [
    'Classes/**/*',
    "#{plugin_to_ios_sdk}/Bridge/**/*.{h,m,mm}",
    "#{plugin_to_ios_sdk}/Mock/**/*.{h,cpp}"
  ]
  s.private_header_files = ["#{plugin_to_ios_sdk}/Mock/**/*.h"]
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    'HEADER_SEARCH_PATHS' => "$(inherited) #{header_paths} #{File.join(ios_sdk_root, 'Bridge')}",
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++17',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -std=gnu++17',
    'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]' => ([ '$(inherited)' ] + device_lib_paths).join(' '),
    'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => ([ '$(inherited)' ] + sim_lib_paths).join(' '),
    'OTHER_LDFLAGS[sdk=iphoneos*]' => device_link_flags,
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' => sim_link_flags
  }

  s.user_target_xcconfig = {
    'ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }

  s.frameworks = [
    'CoreNFC',
    'CoreFoundation',
    'SystemConfiguration'
  ]

  s.requires_arc = true
end
