// TextSignatureGenerator.h
// Generates signature images from text using FreeType
//
// Copyright (c) 2024 IPZS. All rights reserved.

#pragma once

#include <cstdint>
#include <cstddef>
#include <string>
#include <vector>

namespace cie {

/**
 * Generates signature images from text using a custom font.
 * Uses FreeType for font rendering.
 */
class TextSignatureGenerator {
public:
    TextSignatureGenerator();
    ~TextSignatureGenerator();

    // Non-copyable
    TextSignatureGenerator(const TextSignatureGenerator&) = delete;
    TextSignatureGenerator& operator=(const TextSignatureGenerator&) = delete;

    /**
     * Load a font from a memory buffer (TTF/OTF format).
     * @param fontData Pointer to font data
     * @param fontLen Length of font data in bytes
     * @return true if font loaded successfully
     */
    bool LoadFontFromBuffer(const uint8_t* fontData, size_t fontLen);

    /**
     * Load the default embedded font (Style Script).
     * @return true if font loaded successfully
     */
    bool LoadDefaultFont();

    /**
     * Check if a font is currently loaded.
     */
    bool IsFontLoaded() const;

    /**
     * Generate a signature image from text.
     * The output is RGBA raw pixel data.
     *
     * @param text The text to render (UTF-8 encoded)
     * @param maxWidth Maximum width of the output image
     * @param maxHeight Maximum height of the output image
     * @param outRGBA Output buffer for RGBA pixel data
     * @param outWidth Actual width of the generated image
     * @param outHeight Actual height of the generated image
     * @return true if image generated successfully
     */
    bool GenerateSignatureRGBA(
        const std::string& text,
        uint32_t maxWidth,
        uint32_t maxHeight,
        std::vector<uint8_t>& outRGBA,
        uint32_t& outWidth,
        uint32_t& outHeight
    );

    /**
     * Set the text color (default: black).
     * @param r Red component (0-255)
     * @param g Green component (0-255)
     * @param b Blue component (0-255)
     */
    void SetTextColor(uint8_t r, uint8_t g, uint8_t b);

private:
    struct Impl;
    Impl* m_impl;
};

} // namespace cie
