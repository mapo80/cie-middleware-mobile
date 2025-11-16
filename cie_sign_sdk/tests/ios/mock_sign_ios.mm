#include "../mock/mock_transport.h"
#include "PdfSignatureGenerator.h"
#include "SignedDocument.h"
#include "mobile/mock_signer_material.h"

#import <Foundation/Foundation.h>
#include <TargetConditionals.h>

#include <array>
#include <cassert>
#include <cctype>
#include <cstdio>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

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

void persist_signed_pdf(const std::vector<uint8_t>& pdf)
{
#if TARGET_OS_IPHONE
    @autoreleasepool
    {
        NSArray<NSString*>* dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docs = dirs.count > 0 ? dirs[0] : NSTemporaryDirectory();
        NSString* path = [docs stringByAppendingPathComponent:@"mock_signed_ios.pdf"];
        NSData* data = [NSData dataWithBytes:pdf.data() length:pdf.size()];
        if (![data writeToFile:path atomically:YES])
        {
            throw std::runtime_error("Unable to persist signed PDF");
        }
    }
#else
    (void)pdf;
#endif
}

} // namespace

extern "C" bool cie_mock_sign_ios(const uint8_t* pdf_data, size_t pdf_len)
{
    if (!pdf_data || pdf_len == 0)
        return false;

    try
    {
        MockApduTransport transport;
        std::unique_ptr<cie_sign_ctx, decltype(&cie_sign_ctx_destroy)> ctx(
            create_mock_context(transport), cie_sign_ctx_destroy);
        if (!ctx)
            return false;

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

        if (cie_sign_execute(ctx.get(), &req, &result) != CIE_STATUS_OK)
            return false;
        if (!transport.completed())
            return false;
        if (result.output_len == 0)
            return false;

        std::vector<uint8_t> pdf(pdf_data, pdf_data + pdf_len);
        req.input = pdf.data();
        req.input_len = pdf.size();
        req.doc_type = CIE_DOCUMENT_PDF;
        req.pdf = {};
        req.pdf.page_index = 0;
        req.pdf.reason = "Mock reason";
        req.pdf.name = "Mock user";
        req.pdf.location = "Mock city";
        result.output_len = 0;

        if (cie_sign_execute(ctx.get(), &req, &result) != CIE_STATUS_OK)
            return false;

        std::vector<uint8_t> signedPdf(result.output, result.output + result.output_len);
        if (signedPdf.size() <= pdf.size())
            return false;

        persist_signed_pdf(signedPdf);
        verify_signed_pdf(signedPdf);
        return true;
    }
    catch (...)
    {
        return false;
    }
}
