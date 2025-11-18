#include "mobile/cie_sign.h"
#include "mock/mock_transport.h"

#include "PdfSignatureGenerator.h"
#include "SignedDocument.h"
#include "mobile/mock_signer_material.h"

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

namespace {

struct ScopedContext {
    ScopedContext()
    {
        ctx = nullptr;
    }

    ~ScopedContext()
    {
        if (ctx)
        {
            cie_sign_ctx_destroy(ctx);
        }
    }

    cie_sign_ctx* ctx;
    MockApduTransport transport;
};

bool prepare_request(cie_sign_request& request,
    const uint8_t* pdf,
    size_t pdf_len,
    const uint8_t* signature_image,
    size_t signature_image_len,
    uint32_t page_index,
    float left,
    float bottom,
    float width,
    float height,
    const char* reason,
    const char* name,
    const char* location,
    const char** field_ids,
    size_t field_ids_len)
{
    request = {};
    request.input = pdf;
    request.input_len = pdf_len;
    request.doc_type = CIE_DOCUMENT_PDF;
    request.detached = 0;
    static constexpr char kDefaultPin[] = "1234";
    request.pin = kDefaultPin;
    request.pin_len = sizeof(kDefaultPin) - 1;
    request.pdf.page_index = page_index;
    request.pdf.left = left;
    request.pdf.bottom = bottom;
    request.pdf.width = width;
    request.pdf.height = height;
    request.pdf.reason = reason;
    request.pdf.name = name;
    request.pdf.location = location;
    request.pdf.signature_image = signature_image;
    request.pdf.signature_image_len = signature_image_len;
    request.pdf.signature_image_width = 0;
    request.pdf.signature_image_height = 0;
    if (field_ids && field_ids_len > 0)
    {
        request.pdf.field_ids = field_ids;
        request.pdf.field_ids_len = field_ids_len;
    }
    return true;
}

} // namespace

extern "C" {

struct cie_mock_pdf_options {
    uint32_t page_index;
    float left;
    float bottom;
    float width;
    float height;
};

struct cie_mock_pdf_result {
    uint8_t* data;
    size_t length;
};

int cie_mock_sign_pdf(const uint8_t* pdf_bytes,
    size_t pdf_len,
    const uint8_t* signature_image,
    size_t signature_image_len,
    const cie_mock_pdf_options* options,
    const char** field_ids,
    size_t field_ids_len,
    cie_mock_pdf_result* out_result)
{
    if (!pdf_bytes || pdf_len == 0 || !out_result)
        return -1;

    ScopedContext scoped;
    scoped.ctx = create_mock_context(scoped.transport);
    if (!scoped.ctx)
        return -2;

    cie_sign_request request{};
    cie_mock_pdf_options opts = options ? *options : cie_mock_pdf_options{0, 0.1f, 0.1f, 0.4f, 0.12f};

    if (!prepare_request(request,
            pdf_bytes,
            pdf_len,
            signature_image,
            signature_image_len,
            opts.page_index,
            opts.left,
            opts.bottom,
            opts.width,
            opts.height,
            "Dart Mock",
            "SDK",
            "Host",
            field_ids,
            field_ids_len))
    {
        return -3;
    }

    std::vector<uint8_t> output_buffer(1024 * 1024);
    cie_sign_result result{};
    result.output = output_buffer.data();
    result.output_capacity = output_buffer.size();

    auto status = cie_sign_execute(scoped.ctx, &request, &result);
    if (status != CIE_STATUS_OK)
        return static_cast<int>(status);

    out_result->length = result.output_len;
    out_result->data = static_cast<uint8_t*>(std::malloc(result.output_len));
    if (!out_result->data)
        return -4;
    std::memcpy(out_result->data, result.output, result.output_len);

    return CIE_STATUS_OK;
}

void cie_mock_free(void* buffer)
{
    std::free(buffer);
}

} // extern "C"
