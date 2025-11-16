#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

bool cie_mock_sign_ios(const uint8_t* pdf_data, size_t pdf_len);

#ifdef __cplusplus
}
#endif
