#include "PdfVerifier.h"
#include "SignedDocument.h"
#include "ASN1/Name.h"

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <vector>

#ifndef CIE_SIGN_SDK_SOURCE_DIR
#define CIE_SIGN_SDK_SOURCE_DIR "."
#endif

namespace {

void usage(const char *prog)
{
    std::fprintf(stderr,
                 "Usage: %s <signed.pdf> [expected-common-name]\n"
                 "Extracts every embedded CMS signature from the PDF and prints the subject CN.\n"
                 "If expected-common-name is provided the tool fails when no signature matches it.\n",
                 prog);
}

std::vector<uint8_t> read_file(const std::string &path)
{
    std::ifstream file(path, std::ios::binary);
    if (!file)
        throw std::runtime_error("Unable to open PDF: " + path);
    std::vector<uint8_t> buffer((std::istreambuf_iterator<char>(file)),
                                std::istreambuf_iterator<char>());
    if (buffer.empty())
        throw std::runtime_error("PDF is empty: " + path);
    return buffer;
}

} // namespace

int main(int argc, char **argv)
{
    if (argc < 2)
    {
        usage(argv[0]);
        return EXIT_FAILURE;
    }

    const char *pdfPath = argv[1];
    const char *expectedCn = argc >= 3 ? argv[2] : nullptr;

    std::vector<uint8_t> pdfBytes;
    try
    {
        pdfBytes = read_file(pdfPath);
    }
    catch (const std::exception &ex)
    {
        std::fprintf(stderr, "Error: %s\n", ex.what());
        return EXIT_FAILURE;
    }

    PDFVerifier verifier;
    int loadResult = verifier.Load(reinterpret_cast<const char *>(pdfBytes.data()),
                                   static_cast<int>(pdfBytes.size()));
    if (loadResult != 0)
    {
        std::fprintf(stderr, "PdfVerifier failed to load %s (code %d)\n", pdfPath, loadResult);
        return EXIT_FAILURE;
    }

    bool any = false;
    bool matched = false;
    int signatureIndex = 0;

    while (true)
    {
        UUCByteArray cmsArray;
        SignatureAppearanceInfo info{};
        int rc = verifier.GetSignature(signatureIndex, cmsArray, info);
        if (rc < 0)
            break;
        any = true;
        CSignedDocument signedDoc(cmsArray.getContent(), cmsArray.getLength());
        CCertificate signerCert = signedDoc.getSignerCertificate(0);
        CName subject = signerCert.getSubject();
        std::string cn = subject.getField(OID_COMMON_NAME);
        std::printf("Signature #%d subject CN: %s\n", signatureIndex, cn.c_str());
        if (expectedCn && cn == expectedCn)
        {
            matched = true;
        }
        ++signatureIndex;
    }

    if (!any)
    {
        std::fprintf(stderr, "No signatures found inside %s\n", pdfPath);
        return EXIT_FAILURE;
    }

    if (expectedCn && !matched)
    {
        std::fprintf(stderr,
                     "Expected common name '%s' not found in %s\n",
                     expectedCn,
                     pdfPath);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
