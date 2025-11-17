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
    auto pos = pdf.find("/Contents", start);
    if (pos == std::string::npos)
        throw std::runtime_error("Contents not found");
    pos = pdf.find('<', pos);
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

void assert_signature_field_present_on_disk(const char* path)
{
    using namespace PoDoFo;
    PdfMemDocument document;
    try
    {
        document.Load(path);
    }
    catch (const PdfError& err)
    {
        std::fprintf(stderr, "PoDoFo failed to load signed PDF: %s\n", err.what());
        assert(false);
    }

    size_t signatureCount = 0;
    bool appearanceFound = false;
    try
    {
        auto iterable = document.GetFieldsIterator();
        for (auto it = iterable.begin(); it != iterable.end(); ++it)
        {
            PdfField* field = *it;
            if (field && field->GetType() == PdfFieldType::Signature)
            {
                ++signatureCount;
                PdfAnnotationWidget* widget = field->GetWidget();
                if (widget)
                {
                    auto* appearanceDict = widget->GetAppearanceDictionaryObject();
                    if (appearanceDict)
                        appearanceFound = true;
                }
            }
        }
    }
    catch (const PdfError& err)
    {
        std::fprintf(stderr, "PoDoFo failed while iterating fields: %s\n", err.what());
        assert(false);
    }

    assert(signatureCount > 0);
    assert(appearanceFound);
}

void verify_signed_pdf(const std::vector<uint8_t>& pdf)
{
    std::string pdfStr(reinterpret_cast<const char*>(pdf.data()), pdf.size());
    auto sigPos = pdfStr.find("/Type/Sig");
    if (sigPos == std::string::npos)
        throw std::runtime_error("Signature dictionary missing");

    auto byteRange = parseByteRange(pdfStr, sigPos);
    auto signedData = collectSignedData(pdf, byteRange);
    auto hex = extractContentsHex(pdfStr, sigPos);
    auto cmsBytes = decodeHexString(hex);

    UUCByteArray cmsArray;
    cmsArray.append(cmsBytes.data(), static_cast<unsigned int>(cmsBytes.size()));

    CSignedDocument signedDoc(cmsArray.getContent(), cmsArray.getLength());
    UUCByteArray contentArray;
    contentArray.append(signedData.data(), static_cast<unsigned int>(signedData.size()));
    signedDoc.setContent(contentArray);
    CCertificate signerCert = signedDoc.getSignerCertificate(0);
    UUCByteArray certBytes;
    signerCert.toByteArray(certBytes);
    assert(certBytes.getLength() == cie::mobile::mock_signer::kMockCertificateDerLen);
    bool matches = std::equal(certBytes.getContent(),
                              certBytes.getContent() + certBytes.getLength(),
                              cie::mobile::mock_signer::kMockCertificateDer);
    assert(matches);
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

    std::vector<uint8_t> output(65536);
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
    std::vector<uint8_t> signedPdf(result.output, result.output + result.output_len);
    verify_signed_pdf(signedPdf);
    assert(has_appearance_entry(signedPdf));
    if (signedPdf.size() <= pdf.size()) {
        std::fprintf(stderr, "Signed PDF not larger than original\n");
        cie_sign_ctx_destroy(ctx);
        return 7;
    }
    std::ofstream out("mock_signed.pdf", std::ios::binary);
    out.write(reinterpret_cast<const char*>(signedPdf.data()),
              static_cast<std::streamsize>(signedPdf.size()));
    out.close();
    assert_signature_field_present_on_disk("mock_signed.pdf");

    PDFVerifier verifier;
    assert(verifier.Load("mock_signed.pdf") == 0);
    UUCByteArray verifierCms;
    SignatureAppearanceInfo verifierInfo{};
    int verifierSig = verifier.GetSignature(0, verifierCms, verifierInfo);
    assert(verifierSig >= 0);
    CSignedDocument verifierDoc(verifierCms.getContent(), verifierCms.getLength());
    CCertificate verifierCert = verifierDoc.getSignerCertificate(0);
    UUCByteArray verifierCertBytes;
    verifierCert.toByteArray(verifierCertBytes);
    assert(verifierCertBytes.getLength() == cie::mobile::mock_signer::kMockCertificateDerLen);
    bool verifierMatches = std::equal(verifierCertBytes.getContent(),
                                      verifierCertBytes.getContent() + verifierCertBytes.getLength(),
                                      cie::mobile::mock_signer::kMockCertificateDer);
    assert(verifierMatches);

    // Automatic detection without specifying field identifiers
    auto pdfAuto = loadFixture("data/fixtures/sample.pdf");
    req.input = pdfAuto.data();
    req.input_len = pdfAuto.size();
    req.pdf.field_ids = nullptr;
    req.pdf.field_ids_len = 0;
    req.pdf.left = 0.0f;
    req.pdf.bottom = 0.0f;
    req.pdf.width = 0.0f;
    req.pdf.height = 0.0f;
    result.output_len = 0;
    status = cie_sign_execute(ctx, &req, &result);
    assert(status == CIE_STATUS_OK);
    std::vector<uint8_t> autoSigned(result.output, result.output + result.output_len);
    verify_signed_pdf(autoSigned);

    // Previously signed PDF should trigger creation of a new signature field
    req.input = signedPdf.data();
    req.input_len = signedPdf.size();
    req.pdf.left = 0.5f;
    req.pdf.bottom = 0.15f;
    req.pdf.width = 0.25f;
    req.pdf.height = 0.1f;
    req.pdf.field_ids = nullptr;
    req.pdf.field_ids_len = 0;
    result.output_len = 0;
    status = cie_sign_execute(ctx, &req, &result);
    assert(status == CIE_STATUS_OK);
    std::vector<uint8_t> createdField(result.output, result.output + result.output_len);
    verify_signed_pdf(createdField);

    cie_sign_ctx_destroy(ctx);
    return 0;
}
