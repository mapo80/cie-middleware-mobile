// TextSignatureGenerator.cpp
// Generates signature images from text using FreeType
//
// Copyright (c) 2024 IPZS. All rights reserved.

#include "TextSignatureGenerator.h"
#include "fonts/StyleScript_embedded.h"

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_GLYPH_H

#include <algorithm>
#include <cstring>
#include <cmath>

#ifdef ANDROID
#include <android/log.h>
#define LOG_TAG "TextSignatureGenerator"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#define LOGD(...) do { } while(0)
#define LOGE(...) do { } while(0)
#endif

namespace cie {

struct TextSignatureGenerator::Impl {
    FT_Library library = nullptr;
    FT_Face face = nullptr;
    std::vector<uint8_t> fontBuffer; // Keep font data alive
    uint8_t colorR = 0;
    uint8_t colorG = 0;
    uint8_t colorB = 0;

    Impl() = default;

    ~Impl() {
        if (face) {
            FT_Done_Face(face);
            face = nullptr;
        }
        if (library) {
            FT_Done_FreeType(library);
            library = nullptr;
        }
    }

    bool InitLibrary() {
        if (library) return true;
        FT_Error error = FT_Init_FreeType(&library);
        if (error) {
            LOGE("Failed to init FreeType: %d", error);
            return false;
        }
        return true;
    }
};

TextSignatureGenerator::TextSignatureGenerator()
    : m_impl(new Impl())
{
}

TextSignatureGenerator::~TextSignatureGenerator()
{
    delete m_impl;
}

bool TextSignatureGenerator::LoadFontFromBuffer(const uint8_t* fontData, size_t fontLen)
{
    if (!fontData || fontLen == 0) {
        LOGE("Invalid font data");
        return false;
    }

    if (!m_impl->InitLibrary()) {
        return false;
    }

    // Free existing face
    if (m_impl->face) {
        FT_Done_Face(m_impl->face);
        m_impl->face = nullptr;
    }

    // Copy font data to keep it alive
    m_impl->fontBuffer.assign(fontData, fontData + fontLen);

    FT_Error error = FT_New_Memory_Face(
        m_impl->library,
        m_impl->fontBuffer.data(),
        static_cast<FT_Long>(m_impl->fontBuffer.size()),
        0,
        &m_impl->face
    );

    if (error) {
        LOGE("Failed to load font face: %d", error);
        m_impl->fontBuffer.clear();
        return false;
    }

    LOGD("Font loaded: %s %s", m_impl->face->family_name, m_impl->face->style_name);
    return true;
}

bool TextSignatureGenerator::LoadDefaultFont()
{
    return LoadFontFromBuffer(
        fonts::kStyleScriptRegular,
        fonts::kStyleScriptRegular_len
    );
}

bool TextSignatureGenerator::IsFontLoaded() const
{
    return m_impl->face != nullptr;
}

void TextSignatureGenerator::SetTextColor(uint8_t r, uint8_t g, uint8_t b)
{
    m_impl->colorR = r;
    m_impl->colorG = g;
    m_impl->colorB = b;
}

bool TextSignatureGenerator::GenerateSignatureRGBA(
    const std::string& text,
    uint32_t maxWidth,
    uint32_t maxHeight,
    std::vector<uint8_t>& outRGBA,
    uint32_t& outWidth,
    uint32_t& outHeight)
{
    if (!m_impl->face) {
        LOGE("No font loaded");
        return false;
    }

    if (text.empty() || maxWidth == 0 || maxHeight == 0) {
        LOGE("Invalid parameters");
        return false;
    }

    // Start with a reasonable font size and adjust
    // Script fonts typically need more vertical space
    int fontSize = static_cast<int>(maxHeight * 0.6);
    if (fontSize < 12) fontSize = 12;
    if (fontSize > 200) fontSize = 200;

    FT_Error error = FT_Set_Pixel_Sizes(m_impl->face, 0, fontSize);
    if (error) {
        LOGE("Failed to set font size: %d", error);
        return false;
    }

    // Calculate text dimensions
    int textWidth = 0;
    int maxAscender = 0;
    int maxDescender = 0;

    // First pass: measure text
    for (size_t i = 0; i < text.size(); ) {
        // Simple UTF-8 decoding for common characters
        uint32_t codepoint;
        unsigned char c = static_cast<unsigned char>(text[i]);

        if ((c & 0x80) == 0) {
            codepoint = c;
            i += 1;
        } else if ((c & 0xE0) == 0xC0 && i + 1 < text.size()) {
            codepoint = ((c & 0x1F) << 6) | (text[i+1] & 0x3F);
            i += 2;
        } else if ((c & 0xF0) == 0xE0 && i + 2 < text.size()) {
            codepoint = ((c & 0x0F) << 12) | ((text[i+1] & 0x3F) << 6) | (text[i+2] & 0x3F);
            i += 3;
        } else if ((c & 0xF8) == 0xF0 && i + 3 < text.size()) {
            codepoint = ((c & 0x07) << 18) | ((text[i+1] & 0x3F) << 12) |
                        ((text[i+2] & 0x3F) << 6) | (text[i+3] & 0x3F);
            i += 4;
        } else {
            codepoint = '?';
            i += 1;
        }

        FT_UInt glyphIndex = FT_Get_Char_Index(m_impl->face, codepoint);
        error = FT_Load_Glyph(m_impl->face, glyphIndex, FT_LOAD_DEFAULT);
        if (error) continue;

        textWidth += static_cast<int>(m_impl->face->glyph->advance.x >> 6);

        FT_GlyphSlot slot = m_impl->face->glyph;
        int ascender = slot->bitmap_top;
        int descender = static_cast<int>(slot->bitmap.rows) - slot->bitmap_top;

        if (ascender > maxAscender) maxAscender = ascender;
        if (descender > maxDescender) maxDescender = descender;
    }

    // Adjust font size if text is too wide
    if (textWidth > static_cast<int>(maxWidth) && textWidth > 0) {
        double scale = static_cast<double>(maxWidth) / textWidth * 0.95;
        fontSize = static_cast<int>(fontSize * scale);
        if (fontSize < 8) fontSize = 8;

        FT_Set_Pixel_Sizes(m_impl->face, 0, fontSize);

        // Recalculate dimensions
        textWidth = 0;
        maxAscender = 0;
        maxDescender = 0;

        for (size_t i = 0; i < text.size(); ) {
            uint32_t codepoint;
            unsigned char c = static_cast<unsigned char>(text[i]);

            if ((c & 0x80) == 0) {
                codepoint = c;
                i += 1;
            } else if ((c & 0xE0) == 0xC0 && i + 1 < text.size()) {
                codepoint = ((c & 0x1F) << 6) | (text[i+1] & 0x3F);
                i += 2;
            } else if ((c & 0xF0) == 0xE0 && i + 2 < text.size()) {
                codepoint = ((c & 0x0F) << 12) | ((text[i+1] & 0x3F) << 6) | (text[i+2] & 0x3F);
                i += 3;
            } else if ((c & 0xF8) == 0xF0 && i + 3 < text.size()) {
                codepoint = ((c & 0x07) << 18) | ((text[i+1] & 0x3F) << 12) |
                            ((text[i+2] & 0x3F) << 6) | (text[i+3] & 0x3F);
                i += 4;
            } else {
                codepoint = '?';
                i += 1;
            }

            FT_UInt glyphIndex = FT_Get_Char_Index(m_impl->face, codepoint);
            error = FT_Load_Glyph(m_impl->face, glyphIndex, FT_LOAD_DEFAULT);
            if (error) continue;

            textWidth += static_cast<int>(m_impl->face->glyph->advance.x >> 6);

            FT_GlyphSlot slot = m_impl->face->glyph;
            int ascender = slot->bitmap_top;
            int descender = static_cast<int>(slot->bitmap.rows) - slot->bitmap_top;

            if (ascender > maxAscender) maxAscender = ascender;
            if (descender > maxDescender) maxDescender = descender;
        }
    }

    // Calculate final image dimensions
    int textHeight = maxAscender + maxDescender;
    if (textHeight < 1) textHeight = fontSize;

    // Add padding
    int paddingX = std::max(4, textWidth / 20);
    int paddingY = std::max(4, textHeight / 10);

    outWidth = static_cast<uint32_t>(textWidth + paddingX * 2);
    outHeight = static_cast<uint32_t>(textHeight + paddingY * 2);

    // Clamp to max dimensions
    if (outWidth > maxWidth) outWidth = maxWidth;
    if (outHeight > maxHeight) outHeight = maxHeight;

    // Allocate RGBA buffer (transparent background)
    outRGBA.resize(outWidth * outHeight * 4, 0);

    // Render text
    int penX = paddingX;
    int baseline = paddingY + maxAscender;

    for (size_t i = 0; i < text.size(); ) {
        uint32_t codepoint;
        unsigned char c = static_cast<unsigned char>(text[i]);

        if ((c & 0x80) == 0) {
            codepoint = c;
            i += 1;
        } else if ((c & 0xE0) == 0xC0 && i + 1 < text.size()) {
            codepoint = ((c & 0x1F) << 6) | (text[i+1] & 0x3F);
            i += 2;
        } else if ((c & 0xF0) == 0xE0 && i + 2 < text.size()) {
            codepoint = ((c & 0x0F) << 12) | ((text[i+1] & 0x3F) << 6) | (text[i+2] & 0x3F);
            i += 3;
        } else if ((c & 0xF8) == 0xF0 && i + 3 < text.size()) {
            codepoint = ((c & 0x07) << 18) | ((text[i+1] & 0x3F) << 12) |
                        ((text[i+2] & 0x3F) << 6) | (text[i+3] & 0x3F);
            i += 4;
        } else {
            codepoint = '?';
            i += 1;
        }

        FT_UInt glyphIndex = FT_Get_Char_Index(m_impl->face, codepoint);
        error = FT_Load_Glyph(m_impl->face, glyphIndex, FT_LOAD_RENDER);
        if (error) continue;

        FT_GlyphSlot slot = m_impl->face->glyph;
        FT_Bitmap& bitmap = slot->bitmap;

        int glyphX = penX + slot->bitmap_left;
        int glyphY = baseline - slot->bitmap_top;

        // Blit glyph to output buffer
        for (unsigned int row = 0; row < bitmap.rows; ++row) {
            int destY = glyphY + static_cast<int>(row);
            if (destY < 0 || destY >= static_cast<int>(outHeight)) continue;

            for (unsigned int col = 0; col < bitmap.width; ++col) {
                int destX = glyphX + static_cast<int>(col);
                if (destX < 0 || destX >= static_cast<int>(outWidth)) continue;

                unsigned char alpha = bitmap.buffer[row * bitmap.pitch + col];
                if (alpha == 0) continue;

                size_t pixelIndex = (destY * outWidth + destX) * 4;

                // Alpha blending with text color
                uint8_t srcAlpha = alpha;
                uint8_t dstAlpha = outRGBA[pixelIndex + 3];

                if (dstAlpha == 0) {
                    outRGBA[pixelIndex + 0] = m_impl->colorR;
                    outRGBA[pixelIndex + 1] = m_impl->colorG;
                    outRGBA[pixelIndex + 2] = m_impl->colorB;
                    outRGBA[pixelIndex + 3] = srcAlpha;
                } else {
                    // Composite alpha
                    uint16_t outAlpha = srcAlpha + dstAlpha * (255 - srcAlpha) / 255;
                    if (outAlpha > 0) {
                        outRGBA[pixelIndex + 0] = static_cast<uint8_t>(
                            (m_impl->colorR * srcAlpha + outRGBA[pixelIndex + 0] * dstAlpha * (255 - srcAlpha) / 255) / outAlpha);
                        outRGBA[pixelIndex + 1] = static_cast<uint8_t>(
                            (m_impl->colorG * srcAlpha + outRGBA[pixelIndex + 1] * dstAlpha * (255 - srcAlpha) / 255) / outAlpha);
                        outRGBA[pixelIndex + 2] = static_cast<uint8_t>(
                            (m_impl->colorB * srcAlpha + outRGBA[pixelIndex + 2] * dstAlpha * (255 - srcAlpha) / 255) / outAlpha);
                        outRGBA[pixelIndex + 3] = static_cast<uint8_t>(outAlpha);
                    }
                }
            }
        }

        penX += static_cast<int>(slot->advance.x >> 6);
    }

    LOGD("Generated signature: %ux%u for text '%s'", outWidth, outHeight, text.c_str());
    return true;
}

} // namespace cie
