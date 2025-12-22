# frozen_string_literal: true
require 'pathname'

plugin_ios_dir = File.realpath(__dir__)
sdk_root = File.expand_path('../../cie_sign_sdk', plugin_ios_dir)
vcpkg_device_lib = File.join(sdk_root, '.vcpkg/installed/arm64-ios/lib')
sim_podofo_lib = File.join(sdk_root, 'Dependencies-ios-sim/podofo/lib')

device_lib_paths = [
  File.join(sdk_root, 'build/ios'),
  File.join(sdk_root, 'build/ios/Debug-iphoneos'),
  File.join(sdk_root, 'build/ios/Release-iphoneos'),
  vcpkg_device_lib,
  File.join(sdk_root, 'Dependencies-ios/libcurl/lib'),
  File.join(sdk_root, 'Dependencies-ios/cryptopp/lib')
]

sim_lib_paths = [
  File.join(sdk_root, 'build/ios-sim'),
  File.join(sdk_root, 'build/ios-sim/Release-iphonesimulator'),
  File.join(sdk_root, 'build/ios-sim/Debug-iphonesimulator'),
  File.join(sdk_root, 'Dependencies-ios-sim/openssl/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/libcurl/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/libxml2/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/zlib/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/libpng/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/freetype/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/fontconfig/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/podofo/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/bzip2/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/brotli/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/libjpeg/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/libtiff/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/liblzma/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/utf8proc/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/expat/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/cryptopp/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/libiconv/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/date-tz/lib'),
  File.join(sdk_root, 'Dependencies-ios-sim/fmt/lib')
]

# Force-load podofo, fmt, and freetype libraries - separate paths for device and simulator
# This ensures all symbols are included even if not directly referenced
force_load_libs = %w[libpodofo.a libpodofo_private.a libpodofo_3rdparty.a libfmt.a libfreetype.a libfontconfig.a]
podofo_force_load_device = force_load_libs.map { |lib| "-force_load #{File.join(vcpkg_device_lib, lib)}" }.join(' ')
podofo_force_load_sim = force_load_libs.map { |lib| "-force_load #{File.join(sim_podofo_lib, lib)}" }.join(' ')

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

Pod::Spec.new do |s|
  s.name             = 'cie_sign_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter bindings for the CIE signing core.'
  s.description      = 'Internal plugin exposing the CIE signing SDK to Flutter.'
  s.homepage         = 'https://github.com/italia/cie-middleware'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'IPZS' => 'info@ipzs.it' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.private_header_files = 'Classes/Mock/**/*.h'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'ARCHS[sdk=iphonesimulator*]' => 'arm64',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64',
    'HEADER_SEARCH_PATHS' => "$(inherited) #{header_paths}",
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
