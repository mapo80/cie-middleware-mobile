#include "PdfSignatureGenerator.h"

#include "PdfVerifier.h"
#include "UUCLogger.h"
#include "mobile/cie_mobile_log.h"

#include "podofo/main/PdfAnnotation.h"
#include "podofo/main/PdfAnnotationCollection.h"
#include "podofo/main/PdfAnnotationWidget.h"
#include "podofo/main/PdfCatalog.h"
#include "podofo/main/PdfField.h"
#include "podofo/main/PdfImage.h"
#include "podofo/main/PdfPage.h"
#include "podofo/main/PdfPainter.h"
#include "podofo/main/PdfSignature.h"
#include "podofo/main/PdfXObjectForm.h"

#include <png.h>

#include <algorithm>
#include <array>
#include <set>
#include <stdexcept>
#include <vector>
#include <cstdio>
#ifdef ANDROID
#include <android/log.h>
#endif

USE_LOG;

using namespace PoDoFo;

namespace {

constexpr const char* kDefaultFilter = "Adobe.PPKLite";
constexpr const char* kDefaultSubFilter = "ETSI.CAdES.detached";

// Helper struct for PNG write callback
struct PngWriteContext {
    std::vector<uint8_t>* output;
};

static void PngWriteCallback(png_structp png_ptr, png_bytep data, png_size_t length)
{
    auto* ctx = static_cast<PngWriteContext*>(png_get_io_ptr(png_ptr));
    if (ctx && ctx->output) {
        ctx->output->insert(ctx->output->end(), data, data + length);
    }
}

static void PngFlushCallback(png_structp /*png_ptr*/)
{
    // No-op for memory buffer
}

// Convert RGBA raw bytes to PNG format
static bool ConvertRGBAtoPNG(const uint8_t* rgbaData, uint32_t width, uint32_t height,
                              std::vector<uint8_t>& pngOutput)
{
    if (!rgbaData || width == 0 || height == 0) {
        return false;
    }

    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
    if (!png_ptr) {
        cie_mobile_logf("[CIE] ConvertRGBAtoPNG: failed to create png_struct");
        return false;
    }

    png_infop info_ptr = png_create_info_struct(png_ptr);
    if (!info_ptr) {
        png_destroy_write_struct(&png_ptr, nullptr);
        cie_mobile_logf("[CIE] ConvertRGBAtoPNG: failed to create png_info");
        return false;
    }

    if (setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_write_struct(&png_ptr, &info_ptr);
        cie_mobile_logf("[CIE] ConvertRGBAtoPNG: libpng error during encoding");
        return false;
    }

    pngOutput.clear();
    pngOutput.reserve(width * height * 4 / 2); // Estimate compressed size

    PngWriteContext writeCtx;
    writeCtx.output = &pngOutput;
    png_set_write_fn(png_ptr, &writeCtx, PngWriteCallback, PngFlushCallback);

    png_set_IHDR(png_ptr, info_ptr, width, height, 8,
                 PNG_COLOR_TYPE_RGBA, PNG_INTERLACE_NONE,
                 PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

    png_write_info(png_ptr, info_ptr);

    // Write rows
    std::vector<png_bytep> row_pointers(height);
    for (uint32_t y = 0; y < height; ++y) {
        row_pointers[y] = const_cast<png_bytep>(rgbaData + y * width * 4);
    }
    png_write_image(png_ptr, row_pointers.data());
    png_write_end(png_ptr, nullptr);

    png_destroy_write_struct(&png_ptr, &info_ptr);

    cie_mobile_logf("[CIE] ConvertRGBAtoPNG: converted %ux%u RGBA to %zu bytes PNG",
                    width, height, pngOutput.size());
    return true;
}

static std::string getFieldName(PdfField* field)
{
    if (!field)
        return {};
    auto name = field->GetName();
    if (!name.has_value())
        return {};
    auto view = name->GetString();
    if (view.empty())
        return {};
    return std::string(view.data(), view.size());
}

class ExternalPdfSigner : public PdfSigner
{
public:
    ExternalPdfSigner(std::string filter, std::string subfilter)
        : m_filter(std::move(filter)), m_subfilter(std::move(subfilter))
    {
    }

    void Reset() override
    {
        m_buffer.clear();
        m_signature.clear();
    }

    void AppendData(const bufferview& data) override
    {
        auto ptr = reinterpret_cast<const uint8_t*>(data.data());
        m_buffer.insert(m_buffer.end(), ptr, ptr + data.size());
    }

    void ComputeSignature(charbuff& contents, bool dryrun) override
    {
        if (dryrun)
        {
            contents.assign(kMaxSignatureSize, '\0');
        }
        else
        {
            contents.assign(m_signature.data(), m_signature.size());
            if (contents.size() < kMaxSignatureSize)
                contents.resize(kMaxSignatureSize, '\0');
            else if (contents.size() > kMaxSignatureSize)
                contents.resize(kMaxSignatureSize);
        }
    }

    void FetchIntermediateResult(charbuff& result) override
    {
        result.assign(reinterpret_cast<const char*>(m_buffer.data()), m_buffer.size());
    }

    void ComputeSignatureDeferred(const bufferview& processedResult,
        charbuff& contents, bool dryrun) override
    {
        m_signature.assign(processedResult.data(), processedResult.data() + processedResult.size());
        ComputeSignature(contents, dryrun);
    }

    std::string GetSignatureFilter() const override { return m_filter; }
    std::string GetSignatureSubFilter() const override { return m_subfilter; }
    std::string GetSignatureType() const override { return "Sig"; }

private:
    static constexpr size_t kMaxSignatureSize = 16384;
    std::vector<uint8_t> m_buffer;
    std::string m_signature;
    std::string m_filter;
    std::string m_subfilter;
};

static PdfString makeString(const char* value)
{
    return value ? PdfString(value) : PdfString("");
}

static PdfSignature* CreateSignatureField(PdfMemDocument& doc,
    int pageIndex,
    const std::string& fieldName,
    const Rect& rect)
{
    PdfPage& page = doc.GetPages().GetPageAt(pageIndex);
    PdfField& field = page.CreateField(fieldName, PdfFieldType::Signature, rect);
    return dynamic_cast<PdfSignature*>(&field);
}

bool ExtractRectFromDictionary(const PdfSignature& signature, Rect& rectOut)
{
    try
    {
        const PdfObject* rectObj = signature.GetDictionary().GetKey("Rect");
        if (!rectObj || !rectObj->IsArray())
            return false;
        const PdfArray& arr = rectObj->GetArray();
        double left = 0.0, bottom = 0.0, right = 0.0, top = 0.0;
        if (!arr.TryGetAtAs(0, left) ||
            !arr.TryGetAtAs(1, bottom) ||
            !arr.TryGetAtAs(2, right) ||
            !arr.TryGetAtAs(3, top))
        {
            return false;
        }
        const double width = right - left;
        const double height = top - bottom;
        if (width <= 0.0 || height <= 0.0)
            return false;
        rectOut = Rect(left, bottom, width, height);
        return true;
    }
    catch (const PdfError&)
    {
        return false;
    }
    catch (...)
    {
        return false;
    }
}

void EnsureRectDictionaryEntry(PdfSignature& signature, const Rect& rect)
{
    PdfArray array;
    array.Add(PdfObject(static_cast<double>(rect.GetLeft())));
    array.Add(PdfObject(static_cast<double>(rect.GetBottom())));
    array.Add(PdfObject(static_cast<double>(rect.GetRight())));
    array.Add(PdfObject(static_cast<double>(rect.GetTop())));
    signature.GetDictionary().AddKey(PdfName("Rect"), PdfObject(array));
}

void ApplyAppearanceImage(PdfSignature& signature,
                          PdfMemDocument& document,
                          const Rect& rect,
                          const uint8_t* imageData,
                          size_t imageLen,
                          uint32_t imageWidth,
                          uint32_t imageHeight)
{
    cie_mobile_logf("[CIE] ApplyAppearanceImage: len=%zu width=%u height=%u rect=(%.2f,%.2f,%.2f,%.2f)",
                    imageLen, imageWidth, imageHeight,
                    rect.GetLeft(), rect.GetBottom(), rect.Width, rect.Height);

    const double rectWidth = rect.Width;
    const double rectHeight = rect.Height;
    if (!imageData || imageLen == 0 || rectWidth <= 0 || rectHeight <= 0) {
        cie_mobile_logf("[CIE] ApplyAppearanceImage: early return - invalid params (imageData=%p, len=%zu, rectW=%.2f, rectH=%.2f)",
                        (void *)imageData, imageLen, rectWidth, rectHeight);
        return;
    }

    const bool hasRawDimensions = imageWidth > 0 && imageHeight > 0;
    if (hasRawDimensions && imageLen < static_cast<size_t>(imageWidth) * static_cast<size_t>(imageHeight) * 4) {
        cie_mobile_logf("[CIE] ApplyAppearanceImage: early return - raw dimensions but buffer too small");
        return;
    }
    cie_mobile_logf("[CIE] ApplyAppearanceImage: hasRawDimensions=%d, proceeding with image embedding", hasRawDimensions ? 1 : 0);

    try
    {
        Rect appearanceRect(0.0, 0.0, rectWidth, rectHeight);
        auto appearance = document.CreateXObjectForm(appearanceRect);
        PdfPainter painter;
        painter.SetCanvas(*appearance);

        if (hasRawDimensions)
        {
            // Convert RGBA to PNG format because PoDoFo may not support raw RGBA with transparency
            std::vector<uint8_t> pngData;
            if (!ConvertRGBAtoPNG(imageData, imageWidth, imageHeight, pngData)) {
                cie_mobile_logf("[CIE] ApplyAppearanceImage: RGBA to PNG conversion failed, skipping image");
                painter.FinishDrawing();
                return;
            }

            auto image = document.CreateImage();
            bufferview buffer(reinterpret_cast<const char*>(pngData.data()), pngData.size());
            image->LoadFromBuffer(buffer);
            double scaleX = rectWidth / static_cast<double>(image->GetWidth());
            double scaleY = rectHeight / static_cast<double>(image->GetHeight());
            if (scaleX <= 0.0)
                scaleX = 1.0;
            if (scaleY <= 0.0)
                scaleY = 1.0;
            // Use uniform scale to preserve aspect ratio
            double scale = std::min(scaleX, scaleY);
            double scaledWidth = static_cast<double>(image->GetWidth()) * scale;
            double scaledHeight = static_cast<double>(image->GetHeight()) * scale;
            // Center the image within the rectangle
            double offsetX = (rectWidth - scaledWidth) / 2.0;
            double offsetY = (rectHeight - scaledHeight) / 2.0;
            cie_mobile_logf("[CIE] ApplyAppearanceImage: aspect ratio preserved (PNG) - scale=%.4f offset=(%.2f,%.2f) scaledSize=(%.2f,%.2f)",
                            scale, offsetX, offsetY, scaledWidth, scaledHeight);
            painter.DrawImage(*image, offsetX, offsetY, scale, scale);
        }
        else
        {
            auto image = document.CreateImage();
            bufferview buffer(reinterpret_cast<const char*>(imageData), imageLen);
            image->LoadFromBuffer(buffer);
            double scaleX = rectWidth / static_cast<double>(image->GetWidth());
            double scaleY = rectHeight / static_cast<double>(image->GetHeight());
            if (scaleX <= 0.0)
                scaleX = 1.0;
            if (scaleY <= 0.0)
                scaleY = 1.0;
            // Use uniform scale to preserve aspect ratio
            double scale = std::min(scaleX, scaleY);
            double scaledWidth = static_cast<double>(image->GetWidth()) * scale;
            double scaledHeight = static_cast<double>(image->GetHeight()) * scale;
            // Center the image within the rectangle
            double offsetX = (rectWidth - scaledWidth) / 2.0;
            double offsetY = (rectHeight - scaledHeight) / 2.0;
            cie_mobile_logf("[CIE] ApplyAppearanceImage: aspect ratio preserved (encoded) - scale=%.4f offset=(%.2f,%.2f) scaledSize=(%.2f,%.2f)",
                            scale, offsetX, offsetY, scaledWidth, scaledHeight);
            painter.DrawImage(*image, offsetX, offsetY, scale, scale);
        }

        painter.FinishDrawing();

        bool applied = false;
        try
        {
            PdfAnnotationWidget& widget = signature.MustGetWidget();
            widget.SetAppearanceStream(*appearance);
            applied = true;
#ifdef ANDROID
            __android_log_print(ANDROID_LOG_DEBUG, "CieSignNative", "Appearance applied via widget");
#endif
        }
        catch (const PdfError&)
        {
            applied = false;
        }
        catch (...)
        {
            applied = false;
        }

        if (!applied)
        {
            try
            {
                PdfAnnotationWidget* widget = signature.GetWidget();
                PdfDictionary* dict = widget ? &widget->GetDictionary() : nullptr;
                if (!dict)
                {
                    dict = &signature.GetDictionary();
                }
                PdfObject* apObj = dict->GetKey("AP");
                PdfDictionary* apDict = nullptr;
                if (apObj && apObj->IsDictionary())
                {
                    apDict = &apObj->GetDictionary();
                }
                else
                {
                    PdfObject newAp{PdfDictionary()};
                    apObj = &dict->AddKey(PdfName("AP"), newAp);
                    apDict = &apObj->GetDictionary();
                }
                apDict->AddKeyIndirect(PdfName("N"), appearance->GetObject());
#ifdef ANDROID
                __android_log_print(ANDROID_LOG_DEBUG, "CieSignNative", "Appearance applied via fallback dictionary");
#endif
            }
            catch (...)
            {
                std::fprintf(stderr, "PdfSignatureGenerator: Unable to attach appearance dictionary\n");
            }
        }
    }
    catch (const PdfError& err)
    {
#ifdef ANDROID
        __android_log_print(ANDROID_LOG_ERROR, "CieSignNative",
            "PdfSignatureGenerator: Unable to embed signature image: %s", err.what());
#else
        std::fprintf(stderr, "PdfSignatureGenerator: Unable to embed signature image: %s\n", err.what());
#endif
    }
    catch (...)
    {
#ifdef ANDROID
        __android_log_print(ANDROID_LOG_ERROR, "CieSignNative",
            "PdfSignatureGenerator: Unable to embed signature image (unknown error)");
#else
        std::fprintf(stderr, "PdfSignatureGenerator: Unable to embed signature image (unknown error)\n");
#endif
    }
}
} // namespace

PdfSignatureGenerator::PdfSignatureGenerator()
    : m_pPdfDocument(nullptr),
      m_pSignatureField(nullptr),
      m_actualLen(0),
      m_placeholderSize(0),
      m_signatureImageWidth(0),
      m_signatureImageHeight(0)
{
}

PdfSignatureGenerator::~PdfSignatureGenerator() = default;

int PdfSignatureGenerator::Load(const char* pdf, int len)
{
    try
    {
        cie_mobile_logf("[CIE] PdfSignatureGenerator::Load - len=%d", len);
        m_pPdfDocument = std::make_unique<PdfMemDocument>();
        bufferview buffer(pdf, static_cast<size_t>(len));
        m_pPdfDocument->LoadFromBuffer(buffer);
        cie_mobile_logf("[CIE] PdfSignatureGenerator::Load - PDF loaded successfully");
        // Skip page count and signature count on iOS due to PoDoFo compatibility issues
        int nSigns = 0;
        m_actualLen = len;
        m_originalPdfData.assign(pdf, pdf + len);
        m_streamBuffer = m_originalPdfData;
        m_pSignatureField = nullptr;
        m_pSigningContext.reset();
        m_pSigner.reset();
        m_pDevice.reset();
        m_signerId.reset();
        m_subFilter = kDefaultSubFilter;
        return nSigns;
    }
    catch (const PdfError&)
    {
        return -2;
    }
    catch (...)
    {
        return -1;
    }
}

void PdfSignatureGenerator::AddFont(const char* szFontName, const char* szFontPath)
{
    (void)szFontName;
    (void)szFontPath;
}

void PdfSignatureGenerator::InitSignature(int pageIndex, const char* szReason,
    const char* /*szReasonLabel*/, const char* szName,
    const char* /*szNameLabel*/, const char* szLocation,
    const char* /*szLocationLabel*/, const char* szFieldName,
    const char* szSubFilter)
{
    InitSignature(pageIndex, 0, 0, 0, 0, szReason, nullptr, szName, nullptr,
        szLocation, nullptr, szFieldName, szSubFilter, nullptr, nullptr, nullptr, nullptr);
}

void PdfSignatureGenerator::InitSignature(int pageIndex, float left, float bottom,
    float width, float height, const char* szReason,
    const char* /*szReasonLabel*/, const char* szName,
    const char* /*szNameLabel*/, const char* szLocation,
    const char* /*szLocationLabel*/, const char* szFieldName,
    const char* szSubFilter)
{
    InitSignature(pageIndex, left, bottom, width, height, szReason, nullptr, szName,
        nullptr, szLocation, nullptr, szFieldName, szSubFilter, nullptr, nullptr, nullptr, nullptr);
}

void PdfSignatureGenerator::SetSignatureImage(const uint8_t* signatureImageData,
    size_t signatureImageLen,
    uint32_t width,
    uint32_t height)
{
    cie_mobile_logf("[CIE] SetSignatureImage: ptr=%p len=%zu width=%u height=%u",
                    (void *)signatureImageData, signatureImageLen, width, height);
    if (signatureImageData && signatureImageLen > 0)
    {
        m_signatureImage.assign(signatureImageData, signatureImageData + signatureImageLen);
        m_signatureImageWidth = width;
        m_signatureImageHeight = height;
        cie_mobile_logf("[CIE] SetSignatureImage: stored %zu bytes", m_signatureImage.size());
    }
    else
    {
        m_signatureImage.clear();
        m_signatureImageWidth = 0;
        m_signatureImageHeight = 0;
        cie_mobile_logf("[CIE] SetSignatureImage: cleared (no image data)");
    }
}

void PdfSignatureGenerator::InitSignature(int pageIndex, float left, float bottom,
    float width, float height, const char* szReason,
    const char* /*szReasonLabel*/, const char* szName,
    const char* /*szNameLabel*/, const char* szLocation,
    const char* /*szLocationLabel*/, const char* szFieldName,
    const char* szSubFilter, const char* /*szImagePath*/,
    const char* /*szDescription*/, const char* /*szGraphometricData*/,
    const char* /*szVersion*/)
{
    if (!m_pPdfDocument)
        throw std::runtime_error("PDF document not loaded");

    cie_mobile_logf("[CIE] InitSignature: INPUT pageIndex=%d left=%.2f bottom=%.2f width=%.2f height=%.2f",
                    pageIndex, left, bottom, width, height);

    PdfPage& page = m_pPdfDocument->GetPages().GetPageAt(pageIndex);
    Rect cropBox = page.GetCropBox();
    Rect mediaBox = page.GetMediaBox();

    cie_mobile_logf("[CIE] InitSignature: cropBox=(%.2f,%.2f,%.2f,%.2f) mediaBox=(%.2f,%.2f,%.2f,%.2f)",
                    cropBox.GetLeft(), cropBox.GetBottom(), cropBox.Width, cropBox.Height,
                    mediaBox.GetLeft(), mediaBox.GetBottom(), mediaBox.Width, mediaBox.Height);

    const double pageLeft = cropBox.GetLeft();
    const double pageBottom = cropBox.GetBottom();
    const double pageWidth = cropBox.Width;
    const double pageHeight = cropBox.Height;

    // Detect if coordinates are fractional (0-1) or absolute (in points).
    // If ALL values are <= 1.0, treat as fractional; otherwise treat as absolute.
    const bool useFractionalCoords = (left <= 1.0f && bottom <= 1.0f && width <= 1.0f && height <= 1.0f);

    double left0, bottom0, width0, height0;
    if (useFractionalCoords) {
        // Fractional coordinates (0-1) - scale to page dimensions
        left0 = pageLeft + (left * pageWidth);
        bottom0 = pageBottom + (bottom * pageHeight);
        width0 = width * pageWidth;
        height0 = height * pageHeight;
        cie_mobile_logf("[CIE] InitSignature: using FRACTIONAL -> FINAL left=%.2f bottom=%.2f width=%.2f height=%.2f",
                        left0, bottom0, width0, height0);
    } else {
        // Absolute coordinates (points) - use directly
        left0 = left;
        bottom0 = bottom;
        width0 = width;
        height0 = height;
        cie_mobile_logf("[CIE] InitSignature: using ABSOLUTE -> FINAL left=%.2f bottom=%.2f width=%.2f height=%.2f",
                        left0, bottom0, width0, height0);
    }

    Rect rect(left0, bottom0, width0, height0);

    auto fieldName = std::string(szFieldName ? szFieldName : "Signature1");
    PdfSignature* signature = CreateSignatureField(*m_pPdfDocument, pageIndex, fieldName, rect);
    if (!signature)
        throw std::runtime_error("Failed to create signature field");

    PrepareSignatureField(*signature, &rect, szReason, szName, szLocation, szSubFilter);
}

void PdfSignatureGenerator::GetBufferForSignature(UUCByteArray& toSign)
{
    if (!m_pPdfDocument || !m_pSignatureField)
        throw std::runtime_error("Signature not initialized");

    m_pSigningContext = std::make_unique<PdfSigningContext>();
    m_pSigner = std::make_shared<ExternalPdfSigner>(kDefaultFilter, m_subFilter);
    m_signerId = m_pSigningContext->AddSigner(*m_pSignatureField, m_pSigner);

    m_streamBuffer = m_originalPdfData;
    auto containerDevice = std::make_shared<ContainerStreamDevice<std::string>>(
        m_streamBuffer, DeviceAccess::ReadWrite, false);
    m_pDevice = containerDevice;
    m_signingResults = PdfSigningResults{};

    m_pSigningContext->StartSigning(*m_pPdfDocument, m_pDevice, m_signingResults);

    auto it = m_signingResults.Intermediate.find(*m_signerId);
    if (it == m_signingResults.Intermediate.end())
        throw std::runtime_error("Missing intermediate signing buffer");
    m_placeholderSize = it->second.size();

    toSign.removeAll();
    toSign.append(reinterpret_cast<const BYTE*>(it->second.data()),
        static_cast<unsigned int>(it->second.size()));
}

void PdfSignatureGenerator::SetSignature(const char* signature, int len)
{
    if (!m_pSigningContext || !m_signerId)
        throw std::runtime_error("Signing context not initialized");

    PdfSigningResults processed;
    auto& buffer = processed.Intermediate[*m_signerId];
    buffer.assign(signature, signature + len);
    if (m_placeholderSize != 0) {
        if (buffer.size() < m_placeholderSize) {
            buffer.resize(m_placeholderSize, '\0');
        } else if (buffer.size() > m_placeholderSize) {
            buffer.resize(m_placeholderSize);
        }
    }

    m_pSigningContext->FinishSigning(processed);
    m_placeholderSize = 0;
}

void PdfSignatureGenerator::GetSignedPdf(UUCByteArray& signature)
{
    if (!m_pDevice)
        throw std::runtime_error("No signed PDF available");

    std::string data = m_streamBuffer;
    signature.removeAll();
    signature.append(reinterpret_cast<const BYTE*>(data.data()),
        static_cast<unsigned int>(data.size()));
}

bool PdfSignatureGenerator::InitExistingSignatureField(const char* szFieldName,
    const char* szReason,
    const char* szName,
    const char* szLocation,
    const char* szSubFilter)
{
    if (!szFieldName || !m_pPdfDocument)
        return false;
    PdfSignature* signature = FindSignatureField(szFieldName, true);
    if (!signature)
        return false;
    return PrepareSignatureField(*signature, nullptr, szReason, szName, szLocation, szSubFilter);
}

bool PdfSignatureGenerator::InitFirstUnsignedSignatureField(const char* szReason,
    const char* szName,
    const char* szLocation,
    const char* szSubFilter)
{
    if (!m_pPdfDocument)
        return false;
    try
    {
        auto iterable = m_pPdfDocument->GetFieldsIterator();
        for (auto it = iterable.begin(); it != iterable.end(); ++it)
        {
            PdfField* field = *it;
            if (!field || field->GetType() != PdfFieldType::Signature)
                continue;
            auto* signature = dynamic_cast<PdfSignature*>(field);
            if (!signature)
                continue;
            if (IsFieldSigned(*signature))
                continue;
            return PrepareSignatureField(*signature, nullptr, szReason, szName, szLocation, szSubFilter);
        }
    }
    catch (const PdfError&)
    {
        return false;
    }
    catch (...)
    {
        return false;
    }
    auto legacy = ExtractLegacySignatureFields();
    if (!legacy.empty())
    {
        PdfSignature* signature = CreateFieldFromLegacy(legacy.front());
        if (!signature)
            return false;
        return PrepareSignatureField(*signature, nullptr, szReason, szName, szLocation, szSubFilter);
    }
    return false;
}

std::vector<std::string> PdfSignatureGenerator::ListUnsignedSignatureFieldNames() const
{
    std::vector<std::string> names;
    if (!m_pPdfDocument)
        return names;
    try
    {
        auto iterable = m_pPdfDocument->GetFieldsIterator();
        for (auto it = iterable.begin(); it != iterable.end(); ++it)
        {
            PdfField* field = *it;
            if (!field || field->GetType() != PdfFieldType::Signature)
                continue;
            auto* signature = dynamic_cast<PdfSignature*>(field);
            if (!signature)
                continue;
            if (IsFieldSigned(*signature))
                continue;
            auto fieldName = getFieldName(field);
            if (!fieldName.empty())
                names.push_back(std::move(fieldName));
        }
    }
    catch (const PdfError&)
    {
        names.clear();
    }
    catch (...)
    {
        names.clear();
    }
    auto legacy = ExtractLegacySignatureFields();
    for (const auto& info : legacy)
        names.push_back(info.name);
    return names;
}

std::vector<SignatureFieldInfo> PdfSignatureGenerator::ListAllSignatureFields() const
{
    std::vector<SignatureFieldInfo> fields;
    if (!m_pPdfDocument)
        return fields;

    // Track field names we've already seen to avoid duplicates
    std::set<std::string> seenNames;

    try
    {
        auto iterable = m_pPdfDocument->GetFieldsIterator();
        for (auto it = iterable.begin(); it != iterable.end(); ++it)
        {
            PdfField* field = *it;
            if (!field || field->GetType() != PdfFieldType::Signature)
                continue;
            auto* signature = dynamic_cast<PdfSignature*>(field);
            if (!signature)
                continue;

            SignatureFieldInfo info;
            info.name = getFieldName(field);
            if (info.name.empty())
                continue;

            // Skip if we've already seen this field
            if (seenNames.count(info.name) > 0)
                continue;
            seenNames.insert(info.name);

            info.isSigned = IsFieldSigned(*signature);

            // Get widget annotation for position info
            try
            {
                auto* widget = signature->GetWidget();
                if (widget)
                {
                    Rect rect = widget->GetRect();
                    info.left = rect.GetLeft();
                    info.bottom = rect.GetBottom();
                    info.width = rect.Width;
                    info.height = rect.Height;

                    // Get page index
                    auto* page = widget->GetPage();
                    info.pageIndex = page ? static_cast<int>(page->GetIndex()) : 0;
                }
            }
            catch (...)
            {
                // If we can't get rect, use default values
                info.left = 0.0;
                info.bottom = 0.0;
                info.width = 0.0;
                info.height = 0.0;
                info.pageIndex = 0;
            }

            fields.push_back(std::move(info));
        }
    }
    catch (const PdfError&)
    {
    }
    catch (...)
    {
    }

    // Also extract legacy fields
    auto legacy = ExtractLegacySignatureFields();
    for (const auto& legacyInfo : legacy)
    {
        // Skip if we've already seen this field name
        if (seenNames.count(legacyInfo.name) > 0)
            continue;

        SignatureFieldInfo info;
        info.name = legacyInfo.name;
        info.pageIndex = legacyInfo.pageIndex;
        info.left = legacyInfo.rect.GetLeft();
        info.bottom = legacyInfo.rect.GetBottom();
        info.width = legacyInfo.rect.Width;
        info.height = legacyInfo.rect.Height;
        info.isSigned = false; // Legacy fields are always unsigned (that's why they're legacy)

        fields.push_back(std::move(info));
    }

    return fields;
}

PdfSignature* PdfSignatureGenerator::FindSignatureField(const std::string& fieldName,
    bool requireUnsigned)
{
    if (!m_pPdfDocument)
        return nullptr;
    try
    {
        auto iterable = m_pPdfDocument->GetFieldsIterator();
        for (auto it = iterable.begin(); it != iterable.end(); ++it)
        {
            PdfField* field = *it;
            if (!field || field->GetType() != PdfFieldType::Signature)
                continue;
            auto* signatureField = dynamic_cast<PdfSignature*>(field);
            if (!signatureField)
                continue;
#ifdef ANDROID
            auto currentNameDebug = getFieldName(field);
            __android_log_print(ANDROID_LOG_DEBUG, "CieSignNative",
                "FindSignatureField saw field name=%s signed=%d",
                currentNameDebug.c_str(),
                IsFieldSigned(*signatureField) ? 1 : 0);
#endif
            if (!fieldName.empty())
            {
                auto currentName = getFieldName(field);
                if (currentName != fieldName)
                    continue;
            }
            if (requireUnsigned && IsFieldSigned(*signatureField))
                continue;
            return signatureField;
        }
    }
    catch (const PdfError&)
    {
    }
    catch (...)
    {
    }
    if (!fieldName.empty())
    {
        auto legacyFields = ExtractLegacySignatureFields();
        auto itLegacy = std::find_if(legacyFields.begin(), legacyFields.end(),
            [&](const LegacyFieldInfo& info) { return info.name == fieldName; });
        if (itLegacy != legacyFields.end())
        {
            return CreateFieldFromLegacy(*itLegacy);
        }
    }
    else
    {
        auto legacyFields = ExtractLegacySignatureFields();
        if (!legacyFields.empty())
        {
            return CreateFieldFromLegacy(legacyFields.front());
        }
    }
    return nullptr;
}

bool PdfSignatureGenerator::IsFieldSigned(const PdfSignature& signature) const
{
    const PdfObject* value = signature.GetValueObject();
    if (!value || !value->IsDictionary())
        return false;
    const PdfObject* contents = value->GetDictionary().GetKey("Contents");
    if (!contents)
        return false;
    if (contents->IsNull())
        return false;
    return true;
}

bool PdfSignatureGenerator::PrepareSignatureField(PdfSignature& signature,
    const Rect* customRect,
    const char* szReason,
    const char* szName,
    const char* szLocation,
    const char* szSubFilter)
{
    if (szReason && szReason[0])
        signature.SetSignatureReason(makeString(szReason));
    if (szLocation && szLocation[0])
        signature.SetSignatureLocation(makeString(szLocation));
    if (szName && szName[0])
        signature.SetSignerName(makeString(szName));

    PdfDate now;
    signature.SetSignatureDate(now);

    Rect rect;
    bool rectValid = false;
    if (customRect && customRect->Width > 0.0 && customRect->Height > 0.0)
    {
        rect = *customRect;
        rectValid = true;
    }
    if (!rectValid)
    {
        try
        {
            PdfAnnotationWidget* widget = signature.GetWidget();
            if (widget)
            {
                rect = widget->GetRect();
                rectValid = rect.Width > 0.0 && rect.Height > 0.0;
            }
        }
        catch (const PdfError&)
        {
            rectValid = false;
        }
        catch (...)
        {
            rectValid = false;
        }
    }
    if (!rectValid)
    {
        rectValid = ExtractRectFromDictionary(signature, rect);
    }
    if (rectValid)
    {
        EnsureRectDictionaryEntry(signature, rect);
    }

    m_pSignatureField = &signature;
    cie_mobile_logf("[CIE] PrepareSignatureField: m_signatureImage.size()=%zu rectValid=%d rect=(%.2f,%.2f,%.2f,%.2f)",
                    m_signatureImage.size(), rectValid ? 1 : 0,
                    rect.GetLeft(), rect.GetBottom(), rect.Width, rect.Height);
    if (!m_signatureImage.empty() && rectValid)
    {
        cie_mobile_logf("[CIE] PrepareSignatureField: calling ApplyAppearanceImage");
        ApplyAppearanceImage(signature,
                              *m_pPdfDocument,
                              rect,
            m_signatureImage.data(),
            m_signatureImage.size(),
            m_signatureImageWidth,
            m_signatureImageHeight);
    }
    else
    {
        cie_mobile_logf("[CIE] PrepareSignatureField: skipping ApplyAppearanceImage (image empty=%d, rectValid=%d)",
                        m_signatureImage.empty() ? 1 : 0, rectValid ? 1 : 0);
    }
    m_subFilter = szSubFilter && szSubFilter[0] ? szSubFilter : kDefaultSubFilter;
    return true;
}

std::vector<PdfSignatureGenerator::LegacyFieldInfo> PdfSignatureGenerator::ExtractLegacySignatureFields() const
{
    std::vector<LegacyFieldInfo> legacy;
    if (!m_pPdfDocument)
        return legacy;

    try
    {
        PdfCatalog& catalog = m_pPdfDocument->GetCatalog();
        PdfObject* acroObj = catalog.GetDictionary().GetKey("AcroForm");
        if (!acroObj || !acroObj->IsDictionary())
            return legacy;
        PdfObject* fieldsObj = acroObj->GetDictionary().GetKey("Fields");
        if (!fieldsObj || !fieldsObj->IsArray())
            return legacy;
        PdfArray& fieldsArray = fieldsObj->GetArray();
        PdfPageCollection& pages = m_pPdfDocument->GetPages();
        PdfIndirectObjectList& objects = m_pPdfDocument->GetObjects();

        for (unsigned int i = 0; i < fieldsArray.GetSize(); ++i)
        {
            PdfObject& entry = fieldsArray[i];
            if (!entry.IsReference())
                continue;
            PdfObject* resolved = objects.GetObject(entry.GetReference());
            if (!resolved || !resolved->IsDictionary())
                continue;
            PdfDictionary& dict = resolved->GetDictionary();
            const PdfObject* subtype = dict.GetKey("Subtype");
            if (!subtype || !subtype->IsName())
                continue;
            if (subtype->GetName().GetString() != "Widget")
                continue;
            const PdfObject* fieldType = dict.GetKey("FT");
            if (!fieldType || !fieldType->IsName())
                continue;
            if (fieldType->GetName().GetString() != "Sig")
                continue;
            const PdfObject* nameObj = dict.GetKey("T");
            if (!nameObj || !nameObj->IsString())
                continue;
            const PdfObject* rectObj = dict.GetKey("Rect");
            if (!rectObj || !rectObj->IsArray())
                continue;
            const PdfObject* pageObj = dict.GetKey("P");
            if (!pageObj || !pageObj->IsReference())
                continue;
            PdfPage& page = pages.GetPage(pageObj->GetReference());
            Rect rect;
            const PdfArray& arr = rectObj->GetArray();
            double left = 0.0, bottom = 0.0, right = 0.0, top = 0.0;
            if (!arr.TryGetAtAs(0, left) ||
                !arr.TryGetAtAs(1, bottom) ||
                !arr.TryGetAtAs(2, right) ||
                !arr.TryGetAtAs(3, top))
            {
                continue;
            }
            rect = Rect(left, bottom, right - left, top - bottom);
            if (rect.Width <= 0.0 || rect.Height <= 0.0)
                continue;

            LegacyFieldInfo info;
            auto nameView = nameObj->GetString().GetString();
            info.name.assign(nameView.data(), nameView.size());
            info.rect = rect;
            info.pageIndex = static_cast<int>(page.GetIndex());
            info.widgetRef = entry.GetReference();
            legacy.push_back(std::move(info));
        }
    }
    catch (const PdfError&)
    {
    }
    catch (...)
    {
    }
    return legacy;
}

void PdfSignatureGenerator::RemoveLegacyFieldReferences(const LegacyFieldInfo& info,
    const PdfReference& widgetRef)
{
    if (!m_pPdfDocument || !widgetRef.IsIndirect())
        return;
    try
    {
        PdfCatalog& catalog = m_pPdfDocument->GetCatalog();
        PdfObject* acroObj = catalog.GetDictionary().GetKey("AcroForm");
        if (acroObj && acroObj->IsDictionary())
        {
            PdfObject* fieldsObj = acroObj->GetDictionary().GetKey("Fields");
            if (fieldsObj && fieldsObj->IsArray())
            {
                PdfArray& fieldsArray = fieldsObj->GetArray();
                for (unsigned int i = 0; i < fieldsArray.GetSize(); ++i)
                {
                    PdfObject& entry = fieldsArray[i];
                    if (entry.IsReference() && entry.GetReference() == widgetRef)
                    {
                        fieldsArray.RemoveAt(i);
                        break;
                    }
                }
            }
        }

        PdfPage& page = m_pPdfDocument->GetPages().GetPageAt(info.pageIndex);
        page.GetAnnotations().RemoveAnnot(widgetRef);
    }
    catch (...)
    {
    }
}

PdfSignature* PdfSignatureGenerator::CreateFieldFromLegacy(const LegacyFieldInfo& info)
{
    if (!m_pPdfDocument)
        return nullptr;
    PdfSignature* signature = CreateSignatureField(*m_pPdfDocument,
        info.pageIndex,
        info.name,
        info.rect);
    if (!signature)
        return nullptr;
    RemoveLegacyFieldReferences(info, info.widgetRef);
    return signature;
}

const double PdfSignatureGenerator::getWidth(int pageIndex)
{
    if (!m_pPdfDocument)
        return 0.0;
    PdfPage& page = m_pPdfDocument->GetPages().GetPageAt(pageIndex);
    return page.GetMediaBox().Width;
}

const double PdfSignatureGenerator::getHeight(int pageIndex)
{
    if (!m_pPdfDocument)
        return 0.0;
    PdfPage& page = m_pPdfDocument->GetPages().GetPageAt(pageIndex);
    return page.GetMediaBox().Height;
}

int PdfSignatureGenerator::getPageCount() const
{
    if (!m_pPdfDocument)
        return 0;
    return static_cast<int>(m_pPdfDocument->GetPages().GetCount());
}
