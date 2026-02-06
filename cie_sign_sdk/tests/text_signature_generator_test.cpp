// text_signature_generator_test.cpp
// Unit tests for TextSignatureGenerator
//
// Copyright (c) 2024 IPZS. All rights reserved.

#include "TextSignatureGenerator.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <vector>

namespace {

// Minimal valid TTF header for testing invalid font handling
// This is intentionally malformed to test error handling
const uint8_t kInvalidFontData[] = {0x00, 0x01, 0x00, 0x00, 0xFF, 0xFF};

void test_default_constructor()
{
    std::puts("test_default_constructor");
    cie::TextSignatureGenerator gen;
    assert(!gen.IsFontLoaded());
}

void test_load_default_font()
{
    std::puts("test_load_default_font");
    cie::TextSignatureGenerator gen;
    bool loaded = gen.LoadDefaultFont();
    assert(loaded);
    assert(gen.IsFontLoaded());
}

void test_load_font_null_data()
{
    std::puts("test_load_font_null_data");
    cie::TextSignatureGenerator gen;
    bool loaded = gen.LoadFontFromBuffer(nullptr, 100);
    assert(!loaded);
    assert(!gen.IsFontLoaded());
}

void test_load_font_zero_length()
{
    std::puts("test_load_font_zero_length");
    cie::TextSignatureGenerator gen;
    uint8_t data[] = {0x00};
    bool loaded = gen.LoadFontFromBuffer(data, 0);
    assert(!loaded);
    assert(!gen.IsFontLoaded());
}

void test_load_font_invalid_data()
{
    std::puts("test_load_font_invalid_data");
    cie::TextSignatureGenerator gen;
    bool loaded = gen.LoadFontFromBuffer(kInvalidFontData, sizeof(kInvalidFontData));
    assert(!loaded);
    assert(!gen.IsFontLoaded());
}

void test_generate_without_font()
{
    std::puts("test_generate_without_font");
    cie::TextSignatureGenerator gen;
    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("Test", 200, 100, rgba, width, height);
    assert(!result);
    assert(rgba.empty());
}

void test_generate_empty_text()
{
    std::puts("test_generate_empty_text");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();
    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("", 200, 100, rgba, width, height);
    assert(!result);
}

void test_generate_zero_width()
{
    std::puts("test_generate_zero_width");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();
    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("Test", 0, 100, rgba, width, height);
    assert(!result);
}

void test_generate_zero_height()
{
    std::puts("test_generate_zero_height");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();
    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("Test", 200, 0, rgba, width, height);
    assert(!result);
}

void test_generate_simple_text()
{
    std::puts("test_generate_simple_text");
    cie::TextSignatureGenerator gen;
    bool loaded = gen.LoadDefaultFont();
    assert(loaded);

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("Mario Rossi", 400, 150, rgba, width, height);

    assert(result);
    assert(width > 0);
    assert(height > 0);
    assert(rgba.size() == width * height * 4);

    // Check that some pixels have non-zero alpha (text was rendered)
    bool hasContent = false;
    for (size_t i = 3; i < rgba.size(); i += 4) {
        if (rgba[i] > 0) {
            hasContent = true;
            break;
        }
    }
    assert(hasContent);

    std::printf("  Generated image: %ux%u (%zu bytes)\n", width, height, rgba.size());
}

void test_generate_italian_name()
{
    std::puts("test_generate_italian_name");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("Giulia Bianchi", 500, 200, rgba, width, height);

    assert(result);
    assert(width > 0);
    assert(height > 0);
}

void test_generate_with_accents()
{
    std::puts("test_generate_with_accents");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    // Italian name with accents (UTF-8)
    bool result = gen.GenerateSignatureRGBA("Nicolò Città", 500, 200, rgba, width, height);

    assert(result);
    assert(width > 0);
    assert(height > 0);
}

void test_set_text_color()
{
    std::puts("test_set_text_color");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    // Set red color
    gen.SetTextColor(255, 0, 0);

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("Test", 200, 100, rgba, width, height);

    assert(result);

    // Find a pixel with content and verify color
    bool foundRedPixel = false;
    for (size_t i = 0; i + 3 < rgba.size(); i += 4) {
        if (rgba[i + 3] > 128) { // Significant alpha
            // Should be red (R=255, G=0, B=0)
            if (rgba[i] > 200 && rgba[i + 1] < 50 && rgba[i + 2] < 50) {
                foundRedPixel = true;
                break;
            }
        }
    }
    assert(foundRedPixel);
}

void test_set_text_color_blue()
{
    std::puts("test_set_text_color_blue");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    // Set blue color
    gen.SetTextColor(0, 0, 255);

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("Blue", 200, 100, rgba, width, height);

    assert(result);

    // Find a pixel with content and verify color
    bool foundBluePixel = false;
    for (size_t i = 0; i + 3 < rgba.size(); i += 4) {
        if (rgba[i + 3] > 128) { // Significant alpha
            // Should be blue (R=0, G=0, B=255)
            if (rgba[i] < 50 && rgba[i + 1] < 50 && rgba[i + 2] > 200) {
                foundBluePixel = true;
                break;
            }
        }
    }
    assert(foundBluePixel);
}

void test_generate_long_name_scales_down()
{
    std::puts("test_generate_long_name_scales_down");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    // Very long name should fit within constraints
    bool result = gen.GenerateSignatureRGBA(
        "Alessandro Francesco Giovanni Maria Verdi",
        300, 80, rgba, width, height);

    assert(result);
    assert(width <= 300);
    assert(height <= 80);
}

void test_generate_single_character()
{
    std::puts("test_generate_single_character");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("M", 100, 100, rgba, width, height);

    assert(result);
    assert(width > 0);
    assert(height > 0);
}

void test_generate_numbers()
{
    std::puts("test_generate_numbers");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("12345", 200, 100, rgba, width, height);

    assert(result);
    assert(width > 0);
    assert(height > 0);
}

void test_reload_font()
{
    std::puts("test_reload_font");
    cie::TextSignatureGenerator gen;

    // Load default font
    bool loaded1 = gen.LoadDefaultFont();
    assert(loaded1);
    assert(gen.IsFontLoaded());

    // Reload (should replace previous font)
    bool loaded2 = gen.LoadDefaultFont();
    assert(loaded2);
    assert(gen.IsFontLoaded());

    // Should still work
    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("Test", 200, 100, rgba, width, height);
    assert(result);
}

void test_multiple_generations()
{
    std::puts("test_multiple_generations");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    for (int i = 0; i < 5; ++i) {
        std::vector<uint8_t> rgba;
        uint32_t width = 0, height = 0;
        char text[32];
        std::snprintf(text, sizeof(text), "Test %d", i);
        bool result = gen.GenerateSignatureRGBA(text, 200, 100, rgba, width, height);
        assert(result);
        assert(!rgba.empty());
    }
}

void test_rgba_buffer_format()
{
    std::puts("test_rgba_buffer_format");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("RGBA", 200, 100, rgba, width, height);

    assert(result);
    // RGBA format: 4 bytes per pixel
    assert(rgba.size() == width * height * 4);
    // Size should be a multiple of 4
    assert(rgba.size() % 4 == 0);
}

void test_transparent_background()
{
    std::puts("test_transparent_background");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("A", 200, 100, rgba, width, height);

    assert(result);

    // Find corner pixels - they should be transparent
    // Top-left corner
    assert(rgba[3] == 0); // Alpha of pixel (0,0)

    // Count transparent pixels
    size_t transparentCount = 0;
    size_t opaqueCount = 0;
    for (size_t i = 3; i < rgba.size(); i += 4) {
        if (rgba[i] == 0) {
            ++transparentCount;
        } else {
            ++opaqueCount;
        }
    }

    // Background should be mostly transparent
    assert(transparentCount > opaqueCount);
}

void test_small_dimensions()
{
    std::puts("test_small_dimensions");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    // Minimum reasonable dimensions
    bool result = gen.GenerateSignatureRGBA("X", 20, 20, rgba, width, height);

    assert(result);
    assert(width <= 20);
    assert(height <= 20);
}

void test_large_dimensions()
{
    std::puts("test_large_dimensions");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("Large", 2000, 500, rgba, width, height);

    assert(result);
    assert(width <= 2000);
    assert(height <= 500);
}

void test_space_character()
{
    std::puts("test_space_character");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    bool result = gen.GenerateSignatureRGBA("A B", 200, 100, rgba, width, height);

    assert(result);
    // "A B" should be wider than "AB" due to space
    std::vector<uint8_t> rgba2;
    uint32_t width2 = 0, height2 = 0;
    gen.GenerateSignatureRGBA("AB", 200, 100, rgba2, width2, height2);

    assert(width >= width2); // With space should be same or wider
}

void test_special_characters()
{
    std::puts("test_special_characters");
    cie::TextSignatureGenerator gen;
    gen.LoadDefaultFont();

    std::vector<uint8_t> rgba;
    uint32_t width = 0, height = 0;
    // Test with various special characters
    bool result = gen.GenerateSignatureRGBA("A.B-C'D", 300, 100, rgba, width, height);

    assert(result);
    assert(width > 0);
}

void test_destructor_cleanup()
{
    std::puts("test_destructor_cleanup");
    // Create and destroy multiple generators to test cleanup
    for (int i = 0; i < 10; ++i) {
        cie::TextSignatureGenerator gen;
        gen.LoadDefaultFont();
        std::vector<uint8_t> rgba;
        uint32_t width = 0, height = 0;
        gen.GenerateSignatureRGBA("Cleanup", 200, 100, rgba, width, height);
    }
    // If we get here without crash, cleanup works
}

void test_is_font_loaded_states()
{
    std::puts("test_is_font_loaded_states");
    cie::TextSignatureGenerator gen;

    // Initially not loaded
    assert(!gen.IsFontLoaded());

    // After failed load, still not loaded
    gen.LoadFontFromBuffer(nullptr, 0);
    assert(!gen.IsFontLoaded());

    // After successful load
    gen.LoadDefaultFont();
    assert(gen.IsFontLoaded());
}

} // namespace

int main()
{
    std::puts("=== TextSignatureGenerator Tests ===\n");

    test_default_constructor();
    test_load_default_font();
    test_load_font_null_data();
    test_load_font_zero_length();
    test_load_font_invalid_data();
    test_generate_without_font();
    test_generate_empty_text();
    test_generate_zero_width();
    test_generate_zero_height();
    test_generate_simple_text();
    test_generate_italian_name();
    test_generate_with_accents();
    test_set_text_color();
    test_set_text_color_blue();
    test_generate_long_name_scales_down();
    test_generate_single_character();
    test_generate_numbers();
    test_reload_font();
    test_multiple_generations();
    test_rgba_buffer_format();
    test_transparent_background();
    test_small_dimensions();
    test_large_dimensions();
    test_space_character();
    test_special_characters();
    test_destructor_cleanup();
    test_is_font_loaded_states();

    std::puts("\n=== All TextSignatureGenerator Tests Passed ===");
    return 0;
}
