#include "mobile/cie_sign.h"

#include "CSP/IAS.h"
#include "CIESigner.h"
#include "SignatureGenerator.h"
#include "PdfSignatureGenerator.h"
#include "XAdESGenerator.h"
#include "ASN1/UUCByteArray.h"
#include "Util/Array.h"
#include "disigonsdk.h"

#include <algorithm>
#include <array>
#include <cstring>
#include <limits>
#include <memory>
#include <new>
#include <stdexcept>
#include <string>
#include <vector>

#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rsa.h>
#include <openssl/x509.h>

#include "mobile/mock_signer_material.h"

namespace {

constexpr HRESULT kTransmitOk = 0;
constexpr std::array<uint8_t, 4> kMockAtrPrefix = {'M', 'O', 'C', 'K'};

using namespace cie::mobile::mock_signer;

class MockSigner : public CBaseSigner
{
public:
    MockSigner();
    ~MockSigner();

    long GetCertificate(const char *alias, CCertificate **ppCertificate, UUCByteArray &id) override;
    long Sign(UUCByteArray &data, UUCByteArray &id, int algo, UUCByteArray &signature) override;
    long Close() override { return 0; }

private:
    EVP_PKEY *key_ = nullptr;
    std::vector<uint8_t> certificate_;
};

bool is_mock_atr(const ByteDynArray &atr)
{
    if (atr.size() < kMockAtrPrefix.size()) {
        return false;
    }
    return std::equal(kMockAtrPrefix.begin(), kMockAtrPrefix.end(), atr.data());
}

MockSigner::MockSigner()
{
    BIO* keyBio = BIO_new_mem_buf(kMockPrivateKeyPem, -1);
    if (!keyBio)
        throw std::runtime_error("Unable to allocate key BIO");
    key_ = PEM_read_bio_PrivateKey(keyBio, nullptr, nullptr, nullptr);
    BIO_free(keyBio);
    if (!key_)
        throw std::runtime_error("Unable to parse mock private key");

    certificate_.assign(std::begin(kMockCertificateDer), std::end(kMockCertificateDer));
}

MockSigner::~MockSigner()
{
    if (key_) {
        EVP_PKEY_free(key_);
        key_ = nullptr;
    }
}

long MockSigner::GetCertificate(const char *, CCertificate **ppCertificate, UUCByteArray &id)
{
    id.append((BYTE)'1');
    if (!ppCertificate) {
        return CKR_ARGUMENTS_BAD;
    }
    *ppCertificate = new CCertificate(certificate_.data(),
                                      static_cast<int>(certificate_.size()));
    return CKR_OK;
}

long MockSigner::Sign(UUCByteArray &data, UUCByteArray &, int, UUCByteArray &signature)
{
    RSA *rsa = EVP_PKEY_get1_RSA(key_);
    if (!rsa) {
        return CKR_FUNCTION_FAILED;
    }
    std::vector<unsigned char> buffer(static_cast<size_t>(RSA_size(rsa)));
    int len = RSA_private_encrypt(static_cast<int>(data.getLength()),
                                  reinterpret_cast<const unsigned char *>(data.getContent()),
                                  buffer.data(),
                                  rsa,
                                  RSA_PKCS1_PADDING);
    RSA_free(rsa);
    if (len <= 0) {
        return CKR_FUNCTION_FAILED;
    }
    signature.append(buffer.data(), len);
    return CKR_OK;
}

struct cie_sign_ctx_impl {
    cie_apdu_cb apdu_callback = nullptr;
    void *user_data = nullptr;
    std::string last_error;
    ByteDynArray atr;
    std::unique_ptr<IAS> ias;
    bool mock_mode = false;
    std::unique_ptr<MockSigner> mock_signer;
};

struct SensitiveString {
    std::string value;
    ~SensitiveString()
    {
        std::fill(value.begin(), value.end(), '\0');
    }
};

HRESULT mobile_token_transmit(void *data,
                              uint8_t *apdu,
                              DWORD apduSize,
                              uint8_t *resp,
                              DWORD *respSize)
{
    auto *ctx = static_cast<cie_sign_ctx_impl *>(data);
    if (!ctx || !ctx->apdu_callback) {
        return 1;
    }

    uint32_t out_len = respSize ? *respSize : 0;
    int rc = ctx->apdu_callback(ctx->user_data, apdu, apduSize, resp, &out_len);
    if (respSize) {
        *respSize = out_len;
    }

    return rc == 0 ? kTransmitOk : rc;
}

cie_status copy_to_result(cie_sign_ctx_impl *ctx,
                          const UUCByteArray &data,
                          cie_sign_result *result)
{
    if (data.getLength() > result->output_capacity) {
        ctx->last_error = "Output buffer too small";
        result->output_len = 0;
        return CIE_STATUS_INVALID_INPUT;
    }

    std::memcpy(result->output, data.getContent(), data.getLength());
    result->output_len = data.getLength();
    return CIE_STATUS_OK;
}

cie_status map_error(cie_sign_ctx_impl *ctx,
                     const char *stage,
                     long code,
                     cie_status fallback = CIE_STATUS_CARD_ERROR)
{
    ctx->last_error = std::string(stage) + " failed with code " + std::to_string(code);
    return fallback;
}

bool append_input(UUCByteArray &dest, const cie_sign_request *request)
{
    if (request->input_len > static_cast<size_t>(std::numeric_limits<int>::max())) {
        return false;
    }
    dest.append(reinterpret_cast<const BYTE *>(request->input),
                static_cast<unsigned int>(request->input_len));
    return true;
}

cie_status sign_pkcs7(cie_sign_ctx_impl *ctx,
                      CSignatureGenerator &generator,
                      const cie_sign_request *request,
                      cie_sign_result *result)
{
    UUCByteArray data;
    if (!append_input(data, request)) {
        ctx->last_error = "Input too large";
        return CIE_STATUS_INVALID_INPUT;
    }

    generator.SetData(data);

    UUCByteArray pkcs7;
    long rc = generator.Generate(pkcs7, request->detached ? 1 : 0, 0);
    if (rc != CKR_OK) {
        return map_error(ctx, "PKCS#7 generation", rc);
    }

    return copy_to_result(ctx, pkcs7, result);
}

cie_status sign_pdf(cie_sign_ctx_impl *ctx,
                    CSignatureGenerator &generator,
                    const cie_sign_request *request,
                    cie_sign_result *result)
{
    if (request->input_len > static_cast<size_t>(std::numeric_limits<int>::max())) {
        ctx->last_error = "PDF input too large";
        return CIE_STATUS_INVALID_INPUT;
    }

    PdfSignatureGenerator pdfGenerator;
    int signatureCount = pdfGenerator.Load(
        reinterpret_cast<const char *>(request->input),
        static_cast<int>(request->input_len));
    if (signatureCount < 0) {
        ctx->last_error = "Unable to parse PDF";
        return CIE_STATUS_INVALID_INPUT;
    }

    std::string fieldName = "Signature" + std::to_string(signatureCount + 1);
    const char *reason = request->pdf.reason ? request->pdf.reason : "";
    const char *location = request->pdf.location ? request->pdf.location : "";
    const char *name = request->pdf.name ? request->pdf.name : "";

    if (request->pdf.width > 0 && request->pdf.height > 0) {
        pdfGenerator.InitSignature(
            static_cast<int>(request->pdf.page_index),
            request->pdf.left,
            request->pdf.bottom,
            request->pdf.width,
            request->pdf.height,
            reason,
            "",
            name,
            "",
            location,
            "",
            fieldName.c_str(),
            DISIGON_PDF_SUBFILTER_PKCS_DETACHED,
            nullptr,
            nullptr,
            nullptr,
            nullptr);
    } else {
        pdfGenerator.InitSignature(
            static_cast<int>(request->pdf.page_index),
            reason,
            "",
            name,
            "",
            location,
            "",
            fieldName.c_str(),
            DISIGON_PDF_SUBFILTER_PKCS_DETACHED);
    }

    UUCByteArray bufferToSign;
    pdfGenerator.GetBufferForSignature(bufferToSign);

    generator.SetData(bufferToSign);
    generator.SetHashAlgo(CKM_SHA256_RSA_PKCS);

    UUCByteArray pkcs7;
    long rc = generator.Generate(pkcs7, 1, 0);
    if (rc != CKR_OK) {
        return map_error(ctx, "PDF signature generation", rc);
    }

    pdfGenerator.SetSignature(reinterpret_cast<const char *>(pkcs7.getContent()),
                               static_cast<int>(pkcs7.getLength()));

    UUCByteArray signedPdf;
    pdfGenerator.GetSignedPdf(signedPdf);
    return copy_to_result(ctx, signedPdf, result);
}

cie_status sign_xml(cie_sign_ctx_impl *ctx,
                    CSignatureGenerator &generator,
                    const cie_sign_request *request,
                    cie_sign_result *result)
{
    UUCByteArray data;
    if (!append_input(data, request)) {
        ctx->last_error = "Input too large";
        return CIE_STATUS_INVALID_INPUT;
    }

    CXAdESGenerator xades(&generator);
    xades.SetData(data);
    xades.SetXAdES(generator.GetCAdES());
    xades.SetFileName("document.xml");

    UUCByteArray xadesData;
    long rc = xades.Generate(xadesData, request->detached ? 1 : 0, 0);
    if (rc != CKR_OK) {
        return map_error(ctx, "XAdES generation", rc);
    }

    return copy_to_result(ctx, xadesData, result);
}

} // namespace

cie_sign_ctx *cie_sign_ctx_create(cie_apdu_cb cb,
                                  void *user_data,
                                  const uint8_t *atr,
                                  size_t atr_len)
{
    if (!cb || !atr || atr_len == 0) {
        return nullptr;
    }

    auto *ctx = new (std::nothrow) cie_sign_ctx_impl();
    if (!ctx) {
        return nullptr;
    }

    try {
        ByteDynArray atrBuffer(static_cast<size_t>(atr_len));
        std::memcpy(atrBuffer.data(), atr, atr_len);
        ctx->atr = atrBuffer;

        ByteArray atrArray(ctx->atr.data(), ctx->atr.size());
        ctx->apdu_callback = cb;
        ctx->user_data = user_data;
        if (is_mock_atr(ctx->atr)) {
            ctx->mock_mode = true;
        } else {
            ctx->ias = std::make_unique<IAS>(mobile_token_transmit, atrArray);
            ctx->ias->token.setTransmitCallback(mobile_token_transmit, ctx);
        }
    } catch (...) {
        delete ctx;
        return nullptr;
    }

    return reinterpret_cast<cie_sign_ctx *>(ctx);
}

void cie_sign_ctx_destroy(cie_sign_ctx *public_ctx)
{
    auto *ctx = reinterpret_cast<cie_sign_ctx_impl *>(public_ctx);
    delete ctx;
}

cie_status cie_sign_execute(cie_sign_ctx *public_ctx,
                            const cie_sign_request *request,
                            cie_sign_result *result)
{
    auto *ctx = reinterpret_cast<cie_sign_ctx_impl *>(public_ctx);
    if (!ctx || !request || !result || !result->output || result->output_capacity == 0 ||
        !request->input || request->input_len == 0 ||
        (!ctx->mock_mode && !ctx->ias)) {
        if (ctx) {
            ctx->last_error = "Invalid input arguments";
        }
        return CIE_STATUS_INVALID_INPUT;
    }

    result->output_len = 0;

    if (!request->pin || request->pin_len == 0) {
        ctx->last_error = "PIN not provided";
        return CIE_STATUS_INVALID_INPUT;
    }

    SensitiveString pin;
    pin.value.assign(request->pin, request->pin + request->pin_len);
    pin.value.push_back('\0');

    cie_status status = CIE_STATUS_INTERNAL_ERROR;

    try {
        std::unique_ptr<CCIESigner> realSigner;
        CBaseSigner *signerIface = nullptr;

        if (ctx->mock_mode) {
            if (!ctx->mock_signer) {
                ctx->mock_signer = std::make_unique<MockSigner>();
            }
            signerIface = ctx->mock_signer.get();
        } else {
            realSigner = std::make_unique<CCIESigner>(ctx->ias.get());
            long initRes = realSigner->Init(pin.value.c_str());
            if (initRes != 0) {
                return map_error(ctx, "CIE initialization", initRes);
            }
            signerIface = realSigner.get();
        }

        CSignatureGenerator generator(signerIface);
        generator.SetHashAlgo(CKM_SHA256_RSA_PKCS);
        generator.SetCAdES(false);
        char aliasBuf[] = "CIE";
        generator.SetAlias(aliasBuf);

        if (request->tsa.url && request->tsa.url[0]) {
            generator.SetTSA(
                const_cast<char *>(request->tsa.url),
                request->tsa.username ? const_cast<char *>(request->tsa.username) : nullptr,
                request->tsa.password ? const_cast<char *>(request->tsa.password) : nullptr);
        }

        switch (request->doc_type) {
        case CIE_DOCUMENT_PKCS7:
            status = sign_pkcs7(ctx, generator, request, result);
            break;
        case CIE_DOCUMENT_PDF:
            status = sign_pdf(ctx, generator, request, result);
            break;
        case CIE_DOCUMENT_XML:
            status = sign_xml(ctx, generator, request, result);
            break;
        default:
            ctx->last_error = "Unsupported document type";
            status = CIE_STATUS_UNSUPPORTED_FEATURE;
            break;
        }
    } catch (const std::exception &ex) {
        ctx->last_error = ex.what();
        status = CIE_STATUS_INTERNAL_ERROR;
    } catch (...) {
        ctx->last_error = "Unexpected error";
        status = CIE_STATUS_INTERNAL_ERROR;
    }

    return status;
}

const char *cie_sign_get_last_error(cie_sign_ctx *public_ctx)
{
    auto *ctx = reinterpret_cast<cie_sign_ctx_impl *>(public_ctx);
    if (!ctx) {
        return "Invalid context";
    }
    return ctx->last_error.c_str();
}
