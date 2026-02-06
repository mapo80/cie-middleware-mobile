#pragma once

#include <cstdint>
#include <vector>
#include <string>

struct MockApduResponse {
    std::vector<uint8_t> request;
    std::vector<uint8_t> response;
};

struct MockApduFixture {
    std::vector<uint8_t> atr;
    std::vector<MockApduResponse> exchanges;
    std::string description;
};

const MockApduFixture& get_mock_fixture();
