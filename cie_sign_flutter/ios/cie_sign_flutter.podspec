# frozen_string_literal: true
require 'pathname'

plugin_ios_dir = File.realpath(__dir__)
sdk_root = File.expand_path('../../cie_sign_sdk', plugin_ios_dir)
device_lib_paths = [
  File.join(sdk_root, 'build/ios/Release-iphoneos'),
  File.join(sdk_root, 'Dependencies-ios/openssl/lib'),
  File.join(sdk_root, 'Dependencies-ios/libcurl/lib'),
  File.join(sdk_root, 'Dependencies-ios/libxml2/lib'),
  File.join(sdk_root, 'Dependencies-ios/zlib/lib'),
  File.join(sdk_root, 'Dependencies-ios/libpng/lib'),
  File.join(sdk_root, 'Dependencies-ios/freetype/lib'),
  File.join(sdk_root, 'Dependencies-ios/fontconfig/lib'),
  File.join(sdk_root, 'Dependencies-ios/podofo/lib'),
  File.join(sdk_root, 'Dependencies-ios/bzip2/lib'),
  File.join(sdk_root, 'Dependencies-ios/brotli/lib'),
  File.join(sdk_root, 'Dependencies-ios/libjpeg/lib'),
  File.join(sdk_root, 'Dependencies-ios/libtiff/lib'),
  File.join(sdk_root, 'Dependencies-ios/liblzma/lib'),
  File.join(sdk_root, 'Dependencies-ios/utf8proc/lib'),
  File.join(sdk_root, 'Dependencies-ios/expat/lib'),
  File.join(sdk_root, 'Dependencies-ios/cryptopp/lib'),
  File.join(sdk_root, 'Dependencies-ios/libiconv/lib')
]

sim_lib_paths = [
  File.join(sdk_root, 'build/ios-sim/Release-iphonesimulator'),
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
  File.join(sdk_root, 'Dependencies-ios-sim/libiconv/lib')
]

link_flags = %w[
  -lciesign_core
  -lcie_sign_sdk
  -lcrypto
  -lssl
  -lcurl
  -lxml2
  -lz
  -lpng16
  -lfreetype
  -lfontconfig
  -lpodofo
  -lpodofo_private
  -lpodofo_3rdparty
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
].join(' ')

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
    'OTHER_LDFLAGS' => "$(inherited) #{link_flags}"
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
