#include "mock_transport.h"

#include <cstring>
#include <stdexcept>

MockApduTransport::MockApduTransport()
    : fixture_(get_mock_fixture()), index_(0) {}

int MockApduTransport::operator()(const uint8_t* apdu,
                                  uint32_t apdu_len,
                                  uint8_t* resp,
                                  uint32_t* resp_len)
{
    if (index_ >= fixture_.exchanges.size()) {
        return 0x6F00;
    }

    const auto& ex = fixture_.exchanges[index_];
    if (apdu_len != ex.request.size() ||
        !std::equal(ex.request.begin(), ex.request.end(), apdu)) {
        return 0x6A80;
    }

    if (!resp || !resp_len || *resp_len < ex.response.size()) {
        return 0x6C00;
    }

    std::memcpy(resp, ex.response.data(), ex.response.size());
    *resp_len = static_cast<uint32_t>(ex.response.size());
    ++index_;
    return 0;
}

const std::vector<uint8_t>& MockApduTransport::atr() const {
    return fixture_.atr;
}

bool MockApduTransport::completed() const {
    return index_ == fixture_.exchanges.size();
}

cie_sign_ctx* create_mock_context(MockApduTransport& transport)
{
    const auto& atr = transport.atr();
    return cie_sign_ctx_create(
        [](void* ctx, const uint8_t* apdu, uint32_t apdu_len, uint8_t* resp, uint32_t* resp_len) -> int {
            return static_cast<MockApduTransport*>(ctx)->operator()(apdu, apdu_len, resp, resp_len);
        },
        &transport,
        atr.data(),
        atr.size());
}
