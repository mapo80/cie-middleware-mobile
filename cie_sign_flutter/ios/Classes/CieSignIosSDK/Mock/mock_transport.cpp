#include "mock_transport.h"

#include <cstring>
#include <stdexcept>

#include "mobile/cie_platform.h"

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

namespace {

int mock_open(void* user_data, const uint8_t** atr, size_t* atr_len)
{
    if (!user_data || !atr || !atr_len) {
        return -1;
    }
    auto* transport = static_cast<MockApduTransport*>(user_data);
    const auto& fixtureAtr = transport->atr();
    *atr = fixtureAtr.data();
    *atr_len = fixtureAtr.size();
    return 0;
}

int mock_transceive(void* user_data,
                    const uint8_t* apdu,
                    uint32_t apdu_len,
                    uint8_t* resp,
                    uint32_t* resp_len)
{
    auto* transport = static_cast<MockApduTransport*>(user_data);
    if (!transport) {
        return -1;
    }
    return (*transport)(apdu, apdu_len, resp, resp_len);
}

} // namespace

cie_sign_ctx* create_mock_context(MockApduTransport& transport)
{
    cie_platform_nfc_adapter adapter{};
    adapter.user_data = &transport;
    adapter.open = mock_open;
    adapter.transceive = mock_transceive;

    cie_platform_config config{};
    config.nfc = &adapter;

    return cie_sign_ctx_create_with_platform(&config);
}
