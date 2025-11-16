#pragma once

#include "mobile/cie_sign.h"
#include "mock_apdu_sequence.h"
#include <cstddef>

class MockApduTransport {
public:
    MockApduTransport();

    int operator()(const uint8_t* apdu,
                   uint32_t apdu_len,
                   uint8_t* resp,
                   uint32_t* resp_len);

    const std::vector<uint8_t>& atr() const;
    bool completed() const;

private:
    const MockApduFixture& fixture_;
    size_t index_;
};

cie_sign_ctx* create_mock_context(MockApduTransport& transport);
