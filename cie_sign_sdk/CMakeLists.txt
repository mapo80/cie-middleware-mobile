cmake_minimum_required(VERSION 3.15.3)

set(DEPENDENCIES_DIR ${CMAKE_SOURCE_DIR}/Dependencies CACHE PATH "Third-party dependency root")
set(SOURCE_DIR ${CMAKE_SOURCE_DIR}/src)
set(INCLUDE_DIR ${CMAKE_SOURCE_DIR}/include)
set(INSTALL_DIR ${CMAKE_SOURCE_DIR}/../cie-pkcs11/Sign)

message("DEPENDENCIES_DIR: " ${CMAKE_SOURCE_DIR})
message("SOURCE_DIR: " ${CMAKE_SOURCE_DIR})
message("INCLUDE_DIR: " ${CMAKE_SOURCE_DIR})

project(cie_sign_sdk)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(SRC_LIST
    ${SOURCE_DIR}/Base64.cpp
    ${SOURCE_DIR}/BigInteger.cpp
    ${SOURCE_DIR}/BigIntegerAlgorithms.cpp
    ${SOURCE_DIR}/BigIntegerUtils.cpp
    ${SOURCE_DIR}/BigUnsigned.cpp
    ${SOURCE_DIR}/BigUnsignedInABase.cpp
    ${SOURCE_DIR}/CIESigner.cpp
    ${SOURCE_DIR}/CIEEngine.c
    ${SOURCE_DIR}/CIEEngineHelper.c
    ${SOURCE_DIR}/CertStore.cpp
    ${SOURCE_DIR}/CounterSignatureGenerator.cpp
    ${SOURCE_DIR}/SignatureGenerator.cpp
    ${SOURCE_DIR}/LdapCrl.cpp
    ${SOURCE_DIR}/M7MParser.cpp
    ${SOURCE_DIR}/PdfSignatureGenerator.cpp
    ${SOURCE_DIR}/PdfVerifier.cpp
    ${SOURCE_DIR}/SignedDataGeneratorEx.cpp
    ${SOURCE_DIR}/SignedDocument.cpp
    ${SOURCE_DIR}/SignerInfoGenerator.cpp
    ${SOURCE_DIR}/TSAClient.cpp
    ${SOURCE_DIR}/UUCLogger.cpp
    ${SOURCE_DIR}/UUCStringTable.cpp
    ${SOURCE_DIR}/UUCTextFileReader.cpp
    ${SOURCE_DIR}/UUCTextFileWriter.cpp
    ${SOURCE_DIR}/XAdESGenerator.cpp
    ${SOURCE_DIR}/XAdESVerifier.cpp
    ${SOURCE_DIR}/definitions.cpp
    ${SOURCE_DIR}/disigonsdk.cpp
    ${SOURCE_DIR}/ASN1/ASN1BitString.cpp
    ${SOURCE_DIR}/ASN1/ASN1Boolean.cpp
    ${SOURCE_DIR}/ASN1/ASN1GenericSequence.cpp
    ${SOURCE_DIR}/ASN1/ASN1Integer.cpp
    ${SOURCE_DIR}/ASN1/ASN1Null.cpp
    ${SOURCE_DIR}/ASN1/ASN1Object.cpp
    ${SOURCE_DIR}/ASN1/ASN1ObjectIdentifier.cpp
    ${SOURCE_DIR}/ASN1/ASN1Octetstring.cpp
    ${SOURCE_DIR}/ASN1/ASN1OptionalField.cpp
    ${SOURCE_DIR}/ASN1/ASN1Sequence.cpp
    ${SOURCE_DIR}/ASN1/ASN1Setof.cpp
    ${SOURCE_DIR}/ASN1/ASN1UTCTime.cpp
    ${SOURCE_DIR}/ASN1/AlgorithmIdentifier.cpp
    ${SOURCE_DIR}/ASN1/Certificate.cpp
    ${SOURCE_DIR}/ASN1/CertificateInfo.cpp
    ${SOURCE_DIR}/ASN1/ContentInfo.cpp
    ${SOURCE_DIR}/ASN1/ContentType.cpp
    ${SOURCE_DIR}/ASN1/Crl.cpp
    ${SOURCE_DIR}/ASN1/DigestInfo.cpp
    ${SOURCE_DIR}/ASN1/IssuerAndSerialNumber.cpp
    ${SOURCE_DIR}/ASN1/Name.cpp
    ${SOURCE_DIR}/ASN1/OCSPRequest.cpp
    ${SOURCE_DIR}/ASN1/PKIStatusInfo.cpp
    ${SOURCE_DIR}/ASN1/RSAPrivateKey.cpp
    ${SOURCE_DIR}/ASN1/RSAPublicKey.cpp
    ${SOURCE_DIR}/ASN1/RelativeDistinguishedName.cpp
    ${SOURCE_DIR}/ASN1/SignedData.cpp
    ${SOURCE_DIR}/ASN1/SignerInfo.cpp
    ${SOURCE_DIR}/ASN1/SubjectPublicKeyInfo.cpp
    ${SOURCE_DIR}/ASN1/TSTInfo.cpp
    ${SOURCE_DIR}/ASN1/TimeStampData.cpp
    ${SOURCE_DIR}/ASN1/TimeStampRequest.cpp
    ${SOURCE_DIR}/ASN1/TimeStampResponse.cpp
    ${SOURCE_DIR}/ASN1/TimeStampToken.cpp
    ${SOURCE_DIR}/ASN1/UUCBufferedReader.cpp
    ${SOURCE_DIR}/ASN1/UUCByteArray.cpp
    ${SOURCE_DIR}/RSA/desc.c
    ${SOURCE_DIR}/RSA/nn.c
    ${SOURCE_DIR}/RSA/r_encode.c
    ${SOURCE_DIR}/RSA/r_stdlib.c
    ${SOURCE_DIR}/RSA/rc2.c
    ${SOURCE_DIR}/RSA/rc2.h
    ${SOURCE_DIR}/RSA/rsa.c
    ${SOURCE_DIR}/RSA/sha1.c
    ${SOURCE_DIR}/RSA/sha2.c
    ${SOURCE_DIR}/CSP/IAS.cpp
    ${SOURCE_DIR}/CSP/ATR.cpp
    ${SOURCE_DIR}/CSP/ExtAuthKey.cpp
    ${SOURCE_DIR}/Util/Array.cpp
    ${SOURCE_DIR}/Util/CacheLib.cpp
    ${SOURCE_DIR}/Util/CryptoppUtils.cpp
    ${SOURCE_DIR}/Util/funccallinfo.cpp
    ${SOURCE_DIR}/Util/IniSettings.cpp
    ${SOURCE_DIR}/Util/log.cpp
    ${SOURCE_DIR}/Util/ModuleInfo.cpp
    ${SOURCE_DIR}/Util/TLV.cpp
    ${SOURCE_DIR}/Util/util.cpp
    ${SOURCE_DIR}/Util/UtilException.cpp
    ${SOURCE_DIR}/Util/UUCProperties.cpp
    ${SOURCE_DIR}/Util/UUCStringTable.cpp
    ${SOURCE_DIR}/Util/UUCTextFileReader.cpp
    ${SOURCE_DIR}/Util/SyncroMutex.cpp
    ${SOURCE_DIR}/Crypto/AES.cpp
    ${SOURCE_DIR}/Crypto/ASNParser.cpp
    ${SOURCE_DIR}/Crypto/Base64.cpp
    ${SOURCE_DIR}/Crypto/DES3.cpp
    ${SOURCE_DIR}/Crypto/MAC.cpp
    ${SOURCE_DIR}/Crypto/MD5.cpp
    ${SOURCE_DIR}/Crypto/RSA.cpp
    ${SOURCE_DIR}/Crypto/SHA1.cpp
    ${SOURCE_DIR}/Crypto/SHA256.cpp
    ${SOURCE_DIR}/Crypto/SHA512.cpp
    )

list(APPEND SRC_LIST
    ${SOURCE_DIR}/PCSC/APDU.cpp
    ${SOURCE_DIR}/PCSC/Token.cpp
)

add_library(${PROJECT_NAME} STATIC ${SRC_LIST})

set(INCLUDE_LIST
    ${INCLUDE_DIR}
    ${SOURCE_DIR}/ASN1
    ${SOURCE_DIR}
    ${SOURCE_DIR}/RSA
    ${SOURCE_DIR}/PCSC
    ${SOURCE_DIR}/CSP
    ${SOURCE_DIR}/Util
    ${SOURCE_DIR}/Crypto
    ${SOURCE_DIR}/cryptopp
    ${DEPENDENCIES_DIR}/freetype/include/freetype2
    ${DEPENDENCIES_DIR}/libcurl/include
    ${DEPENDENCIES_DIR}/libpng/include
    ${DEPENDENCIES_DIR}/openssl/include
    ${DEPENDENCIES_DIR}/podofo/include
    ${DEPENDENCIES_DIR}/podofo/include/podofo
    /usr/include/PCSC
    /usr/include/
    ${DEPENDENCIES_DIR}/zlib/include
    ${DEPENDENCIES_DIR}/libxml2/include/libxml2
    ${DEPENDENCIES_DIR}/libiconv/include
    ${DEPENDENCIES_DIR}/cryptopp/include
 )

target_include_directories(${PROJECT_NAME} PRIVATE ${INCLUDE_LIST})

set(LIBICONV_LIB_PATH ${DEPENDENCIES_DIR}/libiconv/lib/libiconv.a)

set(CIESIGN_THIRD_PARTY_LIBS
    ${DEPENDENCIES_DIR}/openssl/lib/libcrypto.a
    ${DEPENDENCIES_DIR}/openssl/lib/libssl.a
    ${DEPENDENCIES_DIR}/libcurl/lib/libcurl.a
    ${DEPENDENCIES_DIR}/libxml2/lib/libxml2.a
    ${DEPENDENCIES_DIR}/zlib/lib/libz.a
    ${DEPENDENCIES_DIR}/libpng/lib/libpng16.a
    ${DEPENDENCIES_DIR}/freetype/lib/libfreetype.a
    ${DEPENDENCIES_DIR}/fontconfig/lib/libfontconfig.a
    ${DEPENDENCIES_DIR}/podofo/lib/libpodofo.a
    ${DEPENDENCIES_DIR}/podofo/lib/libpodofo_private.a
    ${DEPENDENCIES_DIR}/podofo/lib/libpodofo_3rdparty.a
    ${DEPENDENCIES_DIR}/bzip2/lib/libbz2.a
    ${DEPENDENCIES_DIR}/brotli/lib/libbrotlienc.a
    ${DEPENDENCIES_DIR}/brotli/lib/libbrotlidec.a
    ${DEPENDENCIES_DIR}/brotli/lib/libbrotlicommon.a
    ${DEPENDENCIES_DIR}/libjpeg/lib/libjpeg.a
    ${DEPENDENCIES_DIR}/libjpeg/lib/libturbojpeg.a
    ${DEPENDENCIES_DIR}/libtiff/lib/libtiff.a
    ${DEPENDENCIES_DIR}/liblzma/lib/liblzma.a
    ${DEPENDENCIES_DIR}/utf8proc/lib/libutf8proc.a
    ${DEPENDENCIES_DIR}/expat/lib/libexpat.a
    ${DEPENDENCIES_DIR}/cryptopp/lib/libcryptopp.a
)

if(EXISTS ${LIBICONV_LIB_PATH})
    list(APPEND CIESIGN_THIRD_PARTY_LIBS ${LIBICONV_LIB_PATH})
else()
    find_library(SYSTEM_ICONV iconv)
    if(SYSTEM_ICONV)
        list(APPEND CIESIGN_THIRD_PARTY_LIBS ${SYSTEM_ICONV})
    endif()
endif()

if(APPLE)
    find_library(COREFOUNDATION_FRAMEWORK CoreFoundation)
    find_library(SYSTEMCONFIG_FRAMEWORK SystemConfiguration)
    if(COREFOUNDATION_FRAMEWORK)
        list(APPEND CIESIGN_THIRD_PARTY_LIBS ${COREFOUNDATION_FRAMEWORK})
    endif()
    if(SYSTEMCONFIG_FRAMEWORK)
        list(APPEND CIESIGN_THIRD_PARTY_LIBS ${SYSTEMCONFIG_FRAMEWORK})
    endif()
endif()

add_library(ciesign_core STATIC
    ${SOURCE_DIR}/mobile/cie_sign_core.cpp
)

target_include_directories(ciesign_core
    PRIVATE ${INCLUDE_LIST}
    PUBLIC ${INCLUDE_DIR}/mobile
)

target_link_libraries(ciesign_core PUBLIC ${PROJECT_NAME} ${CIESIGN_THIRD_PARTY_LIBS})

install(TARGETS ${PROJECT_NAME} DESTINATION ${INSTALL_DIR})
install(FILES ${INCLUDE_DIR}/disigonsdk.h ${INCLUDE_DIR}/CIEEngine.h DESTINATION ${INSTALL_DIR})

install(TARGETS ciesign_core DESTINATION ${INSTALL_DIR})
install(FILES ${INCLUDE_DIR}/mobile/cie_sign.h DESTINATION ${INSTALL_DIR}/mobile)

enable_testing()

add_executable(mock_sign_test
    tests/mock/mock_apdu_sequence.cpp
    tests/mock/mock_transport.cpp
    tests/mock/mock_sign_test.cpp
)
target_include_directories(mock_sign_test PRIVATE
    ${INCLUDE_LIST}
    ${INCLUDE_DIR}/mobile
)
target_link_libraries(mock_sign_test PRIVATE ciesign_core)
target_compile_definitions(mock_sign_test PRIVATE CIE_SIGN_SDK_SOURCE_DIR="${CMAKE_SOURCE_DIR}")

add_test(NAME mock_sign_test COMMAND mock_sign_test)
