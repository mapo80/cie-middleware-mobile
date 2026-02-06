// auto_signature_test.cpp
// Unit tests for auto-signature functionality in mock mode
//
// Copyright (c) 2024 IPZS. All rights reserved.

#include "mobile/cie_sign.h"
#include "mock/mock_transport.h"
#include "TextSignatureGenerator.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

#ifndef CIE_SIGN_SDK_SOURCE_DIR
#define CIE_SIGN_SDK_SOURCE_DIR "."
#endif

namespace {

std::vector<uint8_t> loadFixture(const char* path)
{
    std::string fullPath = std::string(CIE_SIGN_SDK_SOURCE_DIR) + "/" + path;
    std::ifstream in(fullPath, std::ios::binary);
    if (!in) {
        throw std::runtime_error("Unable to open fixture: " + fullPath);
    }
    return std::vector<uint8_t>(std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>());
}

void test_get_signer_info_mock_mode()
{
    std::puts("test_get_signer_info_mock_mode");

    MockApduTransport transport;
    cie_sign_ctx* ctx = create_mock_context(transport);
    assert(ctx != nullptr);

    cie_signer_info info{};
    cie_status status = cie_get_signer_info(ctx, &info);

    assert(status == CIE_STATUS_OK);
    assert(info.given_name[0] != '\0');  // Should have a name
    assert(info.surname[0] != '\0');     // Should have a surname
    assert(info.common_name[0] != '\0'); // Should have common name

    std::printf("  Signer info: %s %s (%s)\n",
                info.given_name, info.surname, info.common_name);

    // Common name should be "given_name surname"
    std::string expectedCommon = std::string(info.given_name) + " " + info.surname;
    assert(std::string(info.common_name) == expectedCommon);

    cie_sign_ctx_destroy(ctx);
}

void test_get_signer_info_null_context()
{
    std::puts("test_get_signer_info_null_context");

    cie_signer_info info{};
    cie_status status = cie_get_signer_info(nullptr, &info);
    assert(status == CIE_STATUS_INVALID_INPUT);
}

void test_get_signer_info_null_info()
{
    std::puts("test_get_signer_info_null_info");

    MockApduTransport transport;
    cie_sign_ctx* ctx = create_mock_context(transport);
    assert(ctx != nullptr);

    cie_status status = cie_get_signer_info(ctx, nullptr);
    assert(status == CIE_STATUS_INVALID_INPUT);

    cie_sign_ctx_destroy(ctx);
}

void test_get_signer_info_cached()
{
    std::puts("test_get_signer_info_cached");

    MockApduTransport transport;
    cie_sign_ctx* ctx = create_mock_context(transport);
    assert(ctx != nullptr);

    // First call
    cie_signer_info info1{};
    cie_status status1 = cie_get_signer_info(ctx, &info1);
    assert(status1 == CIE_STATUS_OK);

    // Second call - should return same cached info
    cie_signer_info info2{};
    cie_status status2 = cie_get_signer_info(ctx, &info2);
    assert(status2 == CIE_STATUS_OK);

    // Names should be the same (cached)
    assert(std::string(info1.given_name) == std::string(info2.given_name));
    assert(std::string(info1.surname) == std::string(info2.surname));
    assert(std::string(info1.common_name) == std::string(info2.common_name));

    cie_sign_ctx_destroy(ctx);
}

void test_pdf_auto_signature_flag()
{
    std::puts("test_pdf_auto_signature_flag");

    MockApduTransport transport;
    cie_sign_ctx* ctx = create_mock_context(transport);
    assert(ctx != nullptr);

    auto pdf = loadFixture("data/fixtures/sample_no_field.pdf");
    std::printf("  Loaded PDF: %zu bytes\n", pdf.size());

    std::vector<uint8_t> output(1024 * 1024);
    cie_sign_result result{};
    result.output = output.data();
    result.output_capacity = output.size();

    cie_sign_request req{};
    req.input = pdf.data();
    req.input_len = pdf.size();
    req.pin = "1234";
    req.pin_len = 4;
    req.doc_type = CIE_DOCUMENT_PDF;

    // Enable auto-signature
    req.pdf.use_auto_signature = 1;
    req.pdf.signer_name_override = nullptr;  // Use mock name
    req.pdf.page_index = 0;
    req.pdf.left = 0.1f;
    req.pdf.bottom = 0.1f;
    req.pdf.width = 0.4f;
    req.pdf.height = 0.12f;
    req.pdf.reason = "Auto-signature test";
    req.pdf.name = "Test User";
    req.pdf.location = "Test Location";

    cie_status status = cie_sign_execute(ctx, &req, &result);

    if (status != CIE_STATUS_OK) {
        std::fprintf(stderr, "  Error: %s\n", cie_sign_get_last_error(ctx));
    }
    assert(status == CIE_STATUS_OK);
    assert(result.output_len > 0);
    assert(result.output_len > pdf.size());  // Should be larger with signature

    std::printf("  Signed PDF: %zu bytes\n", result.output_len);

    cie_sign_ctx_destroy(ctx);
}

void test_pdf_auto_signature_with_name_override()
{
    std::puts("test_pdf_auto_signature_with_name_override");

    MockApduTransport transport;
    cie_sign_ctx* ctx = create_mock_context(transport);
    assert(ctx != nullptr);

    auto pdf = loadFixture("data/fixtures/sample_no_field.pdf");

    std::vector<uint8_t> output(1024 * 1024);
    cie_sign_result result{};
    result.output = output.data();
    result.output_capacity = output.size();

    cie_sign_request req{};
    req.input = pdf.data();
    req.input_len = pdf.size();
    req.pin = "1234";
    req.pin_len = 4;
    req.doc_type = CIE_DOCUMENT_PDF;

    // Enable auto-signature with custom name
    req.pdf.use_auto_signature = 1;
    req.pdf.signer_name_override = "Custom Signature Name";
    req.pdf.page_index = 0;
    req.pdf.left = 0.1f;
    req.pdf.bottom = 0.1f;
    req.pdf.width = 0.4f;
    req.pdf.height = 0.12f;

    cie_status status = cie_sign_execute(ctx, &req, &result);

    if (status != CIE_STATUS_OK) {
        std::fprintf(stderr, "  Error: %s\n", cie_sign_get_last_error(ctx));
    }
    assert(status == CIE_STATUS_OK);
    assert(result.output_len > 0);

    std::printf("  Signed PDF with custom name: %zu bytes\n", result.output_len);

    cie_sign_ctx_destroy(ctx);
}

void test_pdf_no_auto_signature_no_image()
{
    std::puts("test_pdf_no_auto_signature_no_image");

    MockApduTransport transport;
    cie_sign_ctx* ctx = create_mock_context(transport);
    assert(ctx != nullptr);

    auto pdf = loadFixture("data/fixtures/sample_no_field.pdf");

    std::vector<uint8_t> output(1024 * 1024);
    cie_sign_result result{};
    result.output = output.data();
    result.output_capacity = output.size();

    cie_sign_request req{};
    req.input = pdf.data();
    req.input_len = pdf.size();
    req.pin = "1234";
    req.pin_len = 4;
    req.doc_type = CIE_DOCUMENT_PDF;

    // No auto-signature, no image - should still work (invisible signature)
    req.pdf.use_auto_signature = 0;
    req.pdf.signature_image = nullptr;
    req.pdf.signature_image_len = 0;
    req.pdf.page_index = 0;
    req.pdf.left = 0.1f;
    req.pdf.bottom = 0.1f;
    req.pdf.width = 0.4f;
    req.pdf.height = 0.12f;

    cie_status status = cie_sign_execute(ctx, &req, &result);

    if (status != CIE_STATUS_OK) {
        std::fprintf(stderr, "  Error: %s\n", cie_sign_get_last_error(ctx));
    }
    assert(status == CIE_STATUS_OK);
    assert(result.output_len > 0);

    std::printf("  Signed PDF without visual signature: %zu bytes\n", result.output_len);

    cie_sign_ctx_destroy(ctx);
}

void test_text_signature_generator_with_mock_names()
{
    std::puts("test_text_signature_generator_with_mock_names");

    // Test that TextSignatureGenerator can handle all mock names
    const char* mockNames[] = {
        "Mario Rossi",
        "Giulia Bianchi",
        "Luca Verdi",
        "Francesca Russo",
        "Alessandro Ferrari"
    };

    cie::TextSignatureGenerator gen;
    bool loaded = gen.LoadDefaultFont();
    assert(loaded);

    for (const char* name : mockNames) {
        std::vector<uint8_t> rgba;
        uint32_t width = 0, height = 0;
        bool result = gen.GenerateSignatureRGBA(name, 400, 100, rgba, width, height);

        assert(result);
        assert(width > 0);
        assert(height > 0);
        assert(!rgba.empty());

        std::printf("  %s: %ux%u\n", name, width, height);
    }
}

void test_auto_signature_preserves_pdf_validity()
{
    std::puts("test_auto_signature_preserves_pdf_validity");

    MockApduTransport transport;
    cie_sign_ctx* ctx = create_mock_context(transport);
    assert(ctx != nullptr);

    auto pdf = loadFixture("data/fixtures/sample.pdf");

    std::vector<uint8_t> output(1024 * 1024);
    cie_sign_result result{};
    result.output = output.data();
    result.output_capacity = output.size();

    cie_sign_request req{};
    req.input = pdf.data();
    req.input_len = pdf.size();
    req.pin = "1234";
    req.pin_len = 4;
    req.doc_type = CIE_DOCUMENT_PDF;

    req.pdf.use_auto_signature = 1;
    const char* fieldId = "SignatureField1";
    req.pdf.field_ids = &fieldId;
    req.pdf.field_ids_len = 1;

    cie_status status = cie_sign_execute(ctx, &req, &result);
    assert(status == CIE_STATUS_OK);

    // Check PDF magic number is preserved
    assert(result.output_len >= 4);
    assert(output[0] == '%');
    assert(output[1] == 'P');
    assert(output[2] == 'D');
    assert(output[3] == 'F');

    std::printf("  Signed PDF is valid (starts with %%PDF)\n");

    cie_sign_ctx_destroy(ctx);
}

void test_pdf_options_struct()
{
    std::puts("test_pdf_options_struct");

    // Verify the cie_pdf_options struct has all required fields
    cie_pdf_options opts{};

    opts.page_index = 0;
    opts.left = 0.1f;
    opts.bottom = 0.2f;
    opts.width = 0.3f;
    opts.height = 0.1f;
    opts.reason = "Test reason";
    opts.location = "Test location";
    opts.name = "Test name";
    opts.field_ids = nullptr;
    opts.field_ids_len = 0;
    opts.signature_image = nullptr;
    opts.signature_image_len = 0;
    opts.signature_image_width = 0;
    opts.signature_image_height = 0;
    opts.use_auto_signature = 1;  // New field
    opts.signer_name_override = "Override";  // New field

    // Just verify fields exist and can be assigned
    assert(opts.use_auto_signature == 1);
    assert(std::strcmp(opts.signer_name_override, "Override") == 0);
}

void test_signer_info_struct()
{
    std::puts("test_signer_info_struct");

    cie_signer_info info{};

    // Verify struct size allows reasonable name lengths
    assert(sizeof(info.given_name) >= 64);
    assert(sizeof(info.surname) >= 64);
    assert(sizeof(info.common_name) >= 128);

    // Test buffer copying
    const char* testName = "Giuseppe";
    const char* testSurname = "Garibaldi";
    strncpy(info.given_name, testName, sizeof(info.given_name) - 1);
    strncpy(info.surname, testSurname, sizeof(info.surname) - 1);

    assert(std::strcmp(info.given_name, testName) == 0);
    assert(std::strcmp(info.surname, testSurname) == 0);
}

} // namespace

int main()
{
    std::puts("=== Auto-Signature Tests ===\n");

    test_get_signer_info_mock_mode();
    test_get_signer_info_null_context();
    test_get_signer_info_null_info();
    test_get_signer_info_cached();
    test_pdf_auto_signature_flag();
    test_pdf_auto_signature_with_name_override();
    test_pdf_no_auto_signature_no_image();
    test_text_signature_generator_with_mock_names();
    test_auto_signature_preserves_pdf_validity();
    test_pdf_options_struct();
    test_signer_info_struct();

    std::puts("\n=== All Auto-Signature Tests Passed ===");
    return 0;
}
