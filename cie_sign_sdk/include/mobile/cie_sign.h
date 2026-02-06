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
    int use_auto_signature;             ///< If 1 and signature_image is NULL, generate from signer name
    const char *signer_name_override;   ///< Override signer name for auto signature (optional)
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

/* ============================================================
 * PDF Signature Field Extraction API
 * ============================================================ */

/// Information about a single signature field in a PDF.
typedef struct {
    const char *name;       ///< Field name (caller must NOT free)
    int page_index;         ///< Page index (0-based)
    float left;             ///< X position in PDF points
    float bottom;           ///< Y position in PDF points
    float width;            ///< Width in PDF points
    float height;           ///< Height in PDF points
    int is_signed;          ///< 1 if signed, 0 if unsigned
} cie_signature_field_info;

/// Result containing all signature fields from a PDF.
typedef struct {
    cie_signature_field_info *fields;   ///< Array of fields (owned by this struct)
    size_t count;                        ///< Number of fields
} cie_signature_fields_result;

/// Extract signature fields from a PDF document.
/// @param pdf_data Raw PDF bytes
/// @param pdf_len Length of PDF data
/// @param result Output structure (caller must call cie_signature_fields_free)
/// @return CIE_STATUS_OK on success
cie_status cie_pdf_extract_signature_fields(
    const uint8_t *pdf_data,
    size_t pdf_len,
    cie_signature_fields_result *result);

/// Free memory allocated by cie_pdf_extract_signature_fields.
void cie_signature_fields_free(cie_signature_fields_result *result);

/* ============================================================
 * Signer Information API
 * ============================================================ */

/// Information about the signer extracted from the CIE certificate.
typedef struct {
    char given_name[128];   ///< First name (from certificate OID 2.5.4.42)
    char surname[128];      ///< Last name (from certificate OID 2.5.4.4)
    char common_name[256];  ///< Full name (from certificate OID 2.5.4.3)
} cie_signer_info;

/// Get signer information from the CIE certificate.
/// Must be called after successful PIN verification.
/// @param ctx Signing context
/// @param info Output structure for signer information
/// @return CIE_STATUS_OK on success
cie_status cie_get_signer_info(cie_sign_ctx *ctx, cie_signer_info *info);

#ifdef __cplusplus
}
#endif
