#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int (*cie_nfc_open_cb)(void *user_data,
                               const uint8_t **atr,
                               size_t *atr_len);

typedef int (*cie_nfc_transceive_cb)(void *user_data,
                                     const uint8_t *apdu,
                                     uint32_t apdu_len,
                                     uint8_t *resp,
                                     uint32_t *resp_len);

typedef void (*cie_nfc_close_cb)(void *user_data);

typedef struct {
    void *user_data;
    cie_nfc_open_cb open;
    cie_nfc_transceive_cb transceive;
    cie_nfc_close_cb close;
} cie_platform_nfc_adapter;

typedef void (*cie_logger_cb)(void *user_data,
                              const char *tag,
                              const char *message);

typedef struct {
    void *user_data;
    cie_logger_cb log;
} cie_platform_logger;

typedef struct {
    const cie_platform_nfc_adapter *nfc;
    const cie_platform_logger *logger;
    void *legacy_user_data;
    const uint8_t *atr;
    size_t atr_len;
    int reserved;
    int (*legacy_apdu_cb)(void *user_data,
                          const uint8_t *apdu, uint32_t apdu_len,
                          uint8_t *resp, uint32_t *resp_len);
} cie_platform_config;

#ifdef __cplusplus
}
#endif
