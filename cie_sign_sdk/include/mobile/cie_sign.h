#pragma once

#include "cie_platform.h"

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum cie_status {
    CIE_STATUS_OK = 0,
    CIE_STATUS_INVALID_INPUT = 1,
    CIE_STATUS_CARD_ERROR = 2,
    CIE_STATUS_DEPENDENCY_ERROR = 3,
    CIE_STATUS_UNSUPPORTED_FEATURE = 4,
    CIE_STATUS_INTERNAL_ERROR = 5
} cie_status;

typedef struct cie_sign_ctx cie_sign_ctx;

typedef int (*cie_apdu_cb)(void *user_data,
                           const uint8_t *apdu, uint32_t apdu_len,
                           uint8_t *resp, uint32_t *resp_len);

typedef struct {
    const char *reason;
    const char *location;
    const char *name;
    const uint8_t *signature_image;
    size_t signature_image_len;
    uint32_t signature_image_width;
    uint32_t signature_image_height;
    uint32_t page_index;
    float left;
    float bottom;
    float width;
    float height;
    const char *const *field_ids;
    size_t field_ids_len;
} cie_pdf_options;

typedef struct {
    const char *url;
    const char *username;
    const char *password;
} cie_tsa_options;

typedef enum {
    CIE_DOCUMENT_PKCS7 = 0,
    CIE_DOCUMENT_PDF = 1,
    CIE_DOCUMENT_XML = 2
} cie_document_type;

typedef struct {
    const uint8_t *input;
    size_t input_len;
    const char *pin;
    size_t pin_len;
    cie_document_type doc_type;
    int detached;
    cie_pdf_options pdf;
    cie_tsa_options tsa;
} cie_sign_request;

typedef struct {
    uint8_t *output;
    size_t output_capacity;
    size_t output_len;
} cie_sign_result;

cie_sign_ctx *cie_sign_ctx_create(cie_apdu_cb cb,
                                  void *user_data,
                                  const uint8_t *atr,
                                  size_t atr_len);

cie_sign_ctx *cie_sign_ctx_create_with_platform(const cie_platform_config *config);

void cie_sign_ctx_destroy(cie_sign_ctx *ctx);

cie_status cie_sign_execute(cie_sign_ctx *ctx,
                            const cie_sign_request *request,
                            cie_sign_result *result);

cie_status cie_sign_verify_pin(cie_sign_ctx *ctx,
                               const char *pin,
                               size_t pin_len);

const char *cie_sign_get_last_error(cie_sign_ctx *ctx);

#ifdef __cplusplus
}
#endif
