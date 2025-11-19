#include "mobile/cie_sign.h"
#include "mock_transport.h"
#include "PdfSignatureGenerator.h"
#include "PdfVerifier.h"
#include <algorithm>
#include <array>
#include <cassert>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <vector>

#include "SignedDocument.h"
#include "ASN1/Name.h"
#include "mobile/mock_signer_material.h"
#include "podofo/podofo.h"

#ifndef CIE_SIGN_SDK_SOURCE_DIR
#define CIE_SIGN_SDK_SOURCE_DIR "."
#endif

namespace {

int hexValue(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

std::array<long long, 4> parseByteRange(const std::string& pdf, size_t start = 0)
{
    auto pos = pdf.find("/ByteRange", start);
    if (pos == std::string::npos)
        throw std::runtime_error("ByteRange not found");
    pos = pdf.find('[', pos);
    if (pos == std::string::npos)
        throw std::runtime_error("ByteRange bracket missing");
    ++pos;
    std::array<long long, 4> values{};
    for (size_t i = 0; i < values.size(); ++i)
    {
        while (pos < pdf.size() && std::isspace(static_cast<unsigned char>(pdf[pos])))
            ++pos;
        size_t end = pos;
        while (end < pdf.size() && (std::isdigit(static_cast<unsigned char>(pdf[end])) || pdf[end] == '-'))
            ++end;
        if (end == pos)
            throw std::runtime_error("Invalid ByteRange value");
        values[i] = std::stoll(pdf.substr(pos, end - pos));
        pos = end;
    }
    return values;
}

std::vector<uint8_t> collectSignedData(const std::vector<uint8_t>& pdf,
                                       const std::array<long long, 4>& range)
{
    std::vector<uint8_t> data;
    for (size_t i = 0; i < range.size(); i += 2)
    {
        long long offset = range[i];
        long long length = range[i + 1];
        if (offset < 0 || length < 0 || static_cast<size_t>(offset + length) > pdf.size())
            throw std::runtime_error("ByteRange outside PDF");
        data.insert(data.end(), pdf.begin() + offset, pdf.begin() + offset + length);
    }
    return data;
}

std::string extractContentsHex(const std::string& pdf, size_t start = 0)
{
    auto pos = pdf.find('<', start);
    if (pos == std::string::npos)
        throw std::runtime_error("Contents hex start missing");
    auto end = pdf.find('>', pos + 1);
    if (end == std::string::npos)
        throw std::runtime_error("Contents hex end missing");
    return pdf.substr(pos + 1, end - pos - 1);
}

std::vector<uint8_t> decodeHexString(const std::string& hex)
{
    std::vector<uint8_t> out;
    int hi = -1;
    for (char c : hex)
    {
        if (std::isspace(static_cast<unsigned char>(c)))
            continue;
        int val = hexValue(c);
        if (val < 0)
            continue;
        if (hi < 0)
            hi = val;
        else
        {
            out.push_back(static_cast<uint8_t>((hi << 4) | val));
            hi = -1;
        }
    }
    return out;
}

size_t computeDerTotalLength(const std::vector<uint8_t>& data)
{
    if (data.size() < 2 || data[0] != 0x30)
        return 0;
    size_t idx = 1;
    uint8_t lenByte = data[idx++];
    size_t valueLen = 0;
    if ((lenByte & 0x80) == 0)
    {
        valueLen = lenByte;
    }
    else
    {
        uint8_t lenLen = lenByte & 0x7F;
        if (lenLen == 0 || lenLen > sizeof(size_t) || idx + lenLen > data.size())
            return 0;
        for (uint8_t i = 0; i < lenLen; ++i)
        {
            valueLen = (valueLen << 8) | data[idx++];
        }
    }
    size_t totalLen = idx + valueLen;
    if (totalLen > data.size())
        return 0;
    return totalLen;
}

void assert_signature_field_present_on_disk(const char* path, size_t expectedCount)
{
    using namespace PoDoFo;
    PdfMemDocument document;
    try
    {
        document.Load(path);
    }
    catch (const PdfError& err)
    {
        std::fprintf(stderr, "PoDoFo failed to load signed PDF %s: %s\n", path, err.what());
        assert(false);
    }

    size_t signatureCount = 0;
    try
    {
        auto iterable = document.GetFieldsIterator();
        for (auto it = iterable.begin(); it != iterable.end(); ++it)
        {
            PdfField* field = *it;
            if (field && field->GetType() == PdfFieldType::Signature)
            {
                ++signatureCount;
                PdfSignature* signature = dynamic_cast<PdfSignature*>(field);
                assert(signature);
                const PdfObject* value = signature->GetValueObject();
                assert(value && value->IsDictionary());
                const PdfObject* contents = value->GetDictionary().GetKey("Contents");
                assert(contents && !contents->IsNull());
                PdfAnnotationWidget* widget = signature->GetWidget();
                assert(widget != nullptr);
                const PdfObject* ap = widget->GetDictionary().GetKey("AP");
                assert(ap && ap->IsDictionary());
            }
        }
    }
    catch (const PdfError& err)
    {
        std::fprintf(stderr, "PoDoFo failed while iterating fields: %s\n", err.what());
        assert(false);
    }

    assert(signatureCount == expectedCount);
}

void verify_signed_pdf(const std::vector<uint8_t>& pdf)
{
    PDFVerifier verifier;
    int loadResult = verifier.Load(reinterpret_cast<const char*>(pdf.data()),
                                   static_cast<int>(pdf.size()));
    assert(loadResult == 0);

    int signatureIndex = 0;
    bool verifiedAny = false;
    while (true)
    {
        UUCByteArray cmsArray;
        SignatureAppearanceInfo info{};
        int rc = verifier.GetSignature(signatureIndex, cmsArray, info);
        if (rc < 0)
            break;
        CSignedDocument signedDoc(cmsArray.getContent(), cmsArray.getLength());
        CCertificate signerCert = signedDoc.getSignerCertificate(0);
        UUCByteArray certBytes;
        signerCert.toByteArray(certBytes);
        assert(certBytes.getLength() == cie::mobile::mock_signer::kMockCertificateDerLen);
        bool matches = std::equal(certBytes.getContent(),
                                  certBytes.getContent() + certBytes.getLength(),
                                  cie::mobile::mock_signer::kMockCertificateDer);
        assert(matches);
        CName subject = signerCert.getSubject();
        std::string commonName = subject.getField(OID_COMMON_NAME);
        assert(commonName == "Mock Mobile Signer");
        verifiedAny = true;
        ++signatureIndex;
    }
    assert(verifiedAny);
}

bool has_appearance_entry(const std::vector<uint8_t>& pdf)
{
    for (size_t i = 0; i + 2 < pdf.size(); ++i)
    {
        if (pdf[i] == '/' && pdf[i + 1] == 'A' && pdf[i + 2] == 'P')
            return true;
    }
    return false;
}

static void write_bytes_to_file(const std::vector<uint8_t>& pdf, const char* path)
{
    std::ofstream out(path, std::ios::binary);
    out.write(reinterpret_cast<const char*>(pdf.data()),
              static_cast<std::streamsize>(pdf.size()));
}

void assert_single_field_with_appearance(const char* path)
{
    using namespace PoDoFo;
    PdfMemDocument doc;
    doc.Load(path);
    auto iterable = doc.GetFieldsIterator();
    size_t count = 0;
    bool apPresent = false;
    for (auto it = iterable.begin(); it != iterable.end(); ++it)
    {
        PdfField* field = *it;
        if (!field || field->GetType() != PdfFieldType::Signature)
            continue;
        ++count;
        auto* signature = dynamic_cast<PdfSignature*>(field);
        assert(signature);
        PdfAnnotationWidget* widget = signature->GetWidget();
        assert(widget != nullptr);
        const PdfObject* apObj = widget->GetDictionary().GetKey("AP");
        if (apObj && apObj->IsDictionary())
            apPresent = true;
    }
    assert(count == 1);
    assert(apPresent);
}

static std::vector<uint8_t> loadFixture(const char* path)
{
    std::string fullPath = std::string(CIE_SIGN_SDK_SOURCE_DIR) + "/" + path;
    std::ifstream in(fullPath, std::ios::binary);
    if (!in)
        throw std::runtime_error("Unable to open fixture");
    return std::vector<uint8_t>(std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>());
}

} // namespace

int main() {
    MockApduTransport transport;
    cie_sign_ctx* ctx = create_mock_context(transport);
    if (!ctx) {
        std::fprintf(stderr, "Failed to create mock context\n");
        return 1;
    }

    const char pin[] = "1234";
    const uint8_t data[] = {0x01,0x02,0x03};

    cie_sign_request req{};
    req.input = data;
    req.input_len = sizeof(data);
    req.pin = pin;
    req.pin_len = sizeof(pin) - 1;
    req.doc_type = CIE_DOCUMENT_PKCS7;
    req.detached = 0;

    std::vector<uint8_t> output(1024 * 1024);
    cie_sign_result result{};
    result.output = output.data();
    result.output_capacity = output.size();

    cie_status status = cie_sign_execute(ctx, &req, &result);
    if (status != CIE_STATUS_OK) {
        std::fprintf(stderr, "cie_sign_execute failed: %d (%s)\n", status, cie_sign_get_last_error(ctx));
        cie_sign_ctx_destroy(ctx);
        return 2;
    }

    if (!transport.completed()) {
        std::fprintf(stderr, "Mock exchanges not fully consumed\n");
        cie_sign_ctx_destroy(ctx);
        return 3;
    }

    if (result.output_len == 0) {
        std::fprintf(stderr, "Empty signature output\n");
        cie_sign_ctx_destroy(ctx);
        return 4;
    }

    cie_status verify_status = cie_sign_verify_pin(ctx, pin, sizeof(pin) - 1);
    if (verify_status != CIE_STATUS_OK) {
        std::fprintf(stderr, "cie_sign_verify_pin failed: %d (%s)\n", verify_status, cie_sign_get_last_error(ctx));
        cie_sign_ctx_destroy(ctx);
        return 5;
    }

    verify_status = cie_sign_verify_pin(ctx, nullptr, 0);
    if (verify_status != CIE_STATUS_INVALID_INPUT) {
        std::fprintf(stderr, "cie_sign_verify_pin should fail on invalid input\n");
        cie_sign_ctx_destroy(ctx);
        return 6;
    }

    std::printf("Mock signature generated, %zu bytes\n", result.output_len);

    // PDF signing workflow through cie_sign_execute
    auto pdf = loadFixture("data/fixtures/sample.pdf");
    auto signatureImage = loadFixture("data/fixtures/signature.png");
    std::printf("Loaded sample PDF (%zu bytes)\n", pdf.size());
    req.input = pdf.data();
    req.input_len = pdf.size();
    req.doc_type = CIE_DOCUMENT_PDF;
    req.pdf = {};
    req.pdf.page_index = 0;
    req.pdf.reason = "Mock reason";
    req.pdf.name = "Mock user";
    req.pdf.location = "Mock city";
    const char* fieldId = "SignatureField1";
    req.pdf.field_ids = &fieldId;
    req.pdf.field_ids_len = 1;
    req.pdf.left = 0.1f;
    req.pdf.bottom = 0.1f;
    req.pdf.width = 0.4f;
    req.pdf.height = 0.12f;
    req.pdf.signature_image = signatureImage.data();
    req.pdf.signature_image_len = signatureImage.size();
    req.pdf.signature_image_width = 0;
    req.pdf.signature_image_height = 0;
    result.output_len = 0;
    status = cie_sign_execute(ctx, &req, &result);
    if (status != CIE_STATUS_OK) {
        std::fprintf(stderr, "PDF signing failed: %d (%s)\n", status, cie_sign_get_last_error(ctx));
        cie_sign_ctx_destroy(ctx);
        return 6;
    }
    if (result.output_len == 0) {
        std::fprintf(stderr, "Scenario 1 produced empty output\n");
        cie_sign_ctx_destroy(ctx);
        return 7;
    }
    std::puts("Scenario 1: signing existing field by ID");
    std::vector<uint8_t> signedPdf(result.output, result.output + result.output_len);
    write_bytes_to_file(signedPdf, "mock_signed.pdf");
    verify_signed_pdf(signedPdf);
    assert(has_appearance_entry(signedPdf));
    if (signedPdf.size() <= pdf.size()) {
        std::fprintf(stderr, "Signed PDF not larger than original\n");
        cie_sign_ctx_destroy(ctx);
        return 7;
    }
    assert_signature_field_present_on_disk("mock_signed.pdf", 1);

    PDFVerifier verifier;
    int pdfLoadResult = verifier.Load("mock_signed.pdf");
    if (pdfLoadResult != 0)
    {
        std::fprintf(stderr, "PDFVerifier Load failed: %d\n", pdfLoadResult);
        cie_sign_ctx_destroy(ctx);
        return 8;
    }
    UUCByteArray verifierCms;
    SignatureAppearanceInfo verifierInfo{};
    int verifierSig = verifier.GetSignature(0, verifierCms, verifierInfo);
    if (verifierSig < 0)
    {
        std::fprintf(stderr, "PDFVerifier failed: %d\n", verifierSig);
        cie_sign_ctx_destroy(ctx);
        return 8;
    }
    CSignedDocument verifierDoc(verifierCms.getContent(), verifierCms.getLength());
    CCertificate verifierCert = verifierDoc.getSignerCertificate(0);
    UUCByteArray verifierCertBytes;
    verifierCert.toByteArray(verifierCertBytes);
    assert(verifierCertBytes.getLength() == cie::mobile::mock_signer::kMockCertificateDerLen);
    bool verifierMatches = std::equal(verifierCertBytes.getContent(),
                                      verifierCertBytes.getContent() + verifierCertBytes.getLength(),
                                      cie::mobile::mock_signer::kMockCertificateDer);
    assert(verifierMatches);
    assert_single_field_with_appearance("mock_signed.pdf");

    // Scenario 2: PDF senza campi firma -> creazione di un nuovo campo
    std::puts("Scenario 2: signing PDF without existing fields (new field)");
    auto pdfNoField = loadFixture("data/fixtures/sample_no_field.pdf");
    req.input = pdfNoField.data();
    req.input_len = pdfNoField.size();
    req.pdf.field_ids = nullptr;
    req.pdf.field_ids_len = 0;
    req.pdf.page_index = 0;
    req.pdf.left = 0.2f;
    req.pdf.bottom = 0.15f;
    req.pdf.width = 0.35f;
    req.pdf.height = 0.12f;
    result.output_len = 0;
    status = cie_sign_execute(ctx, &req, &result);
    if (status != CIE_STATUS_OK || result.output_len == 0) {
        std::fprintf(stderr, "Scenario 2 failed: status=%d len=%zu (%s)\n",
                     status, result.output_len, cie_sign_get_last_error(ctx));
        cie_sign_ctx_destroy(ctx);
        return 8;
    }
    std::vector<uint8_t> createdPdf(result.output, result.output + result.output_len);
    write_bytes_to_file(createdPdf, "mock_signed_created.pdf");
    verify_signed_pdf(createdPdf);
    assert_signature_field_present_on_disk("mock_signed_created.pdf", 1);

    // Scenario 3: PDF con più campi firma, nessun ID esplicito
    std::puts("Scenario 3: signing PDF with multiple fields, no IDs provided");
    auto pdfMulti = loadFixture("data/fixtures/sample_multi_field.pdf");
    req.input = pdfMulti.data();
    req.input_len = pdfMulti.size();
    req.pdf.field_ids = nullptr;
    req.pdf.field_ids_len = 0;
    req.pdf.left = 0.0f;
    req.pdf.bottom = 0.0f;
    req.pdf.width = 0.0f;
    req.pdf.height = 0.0f;
    result.output_len = 0;
    status = cie_sign_execute(ctx, &req, &result);
    if (status != CIE_STATUS_OK || result.output_len == 0) {
        std::fprintf(stderr, "Scenario 3 failed: status=%d len=%zu (%s)\n",
                     status, result.output_len, cie_sign_get_last_error(ctx));
        cie_sign_ctx_destroy(ctx);
        return 9;
    }
    std::vector<uint8_t> multiSigned(result.output, result.output + result.output_len);
    write_bytes_to_file(multiSigned, "mock_signed_multi.pdf");
    verify_signed_pdf(multiSigned);
    // Multi-signature layout validated via verify_signed_pdf

    cie_sign_ctx_destroy(ctx);
    return 0;
}
