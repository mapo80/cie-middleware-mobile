#include "PdfSignatureGenerator.h"

#include "PdfVerifier.h"
#include "UUCLogger.h"

#include "podofo/main/PdfAnnotation.h"
#include "podofo/main/PdfAnnotationWidget.h"
#include "podofo/main/PdfField.h"
#include "podofo/main/PdfImage.h"
#include "podofo/main/PdfPainter.h"
#include "podofo/main/PdfSignature.h"
#include "podofo/main/PdfXObjectForm.h"

#include <stdexcept>
#include <vector>
#include <cstdio>

USE_LOG;

using namespace PoDoFo;

namespace {

constexpr const char* kDefaultFilter = "Adobe.PPKLite";
constexpr const char* kDefaultSubFilter = "ETSI.CAdES.detached";

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

void ApplyAppearanceImage(PdfSignature& signature,
                          PdfMemDocument& document,
                          const Rect& rect,
                          const uint8_t* imageData,
                          size_t imageLen,
                          uint32_t imageWidth,
                          uint32_t imageHeight)
{
    const double rectWidth = rect.Width;
    const double rectHeight = rect.Height;
    if (!imageData || imageLen == 0 || rectWidth <= 0 || rectHeight <= 0)
        return;

    const bool hasRawDimensions = imageWidth > 0 && imageHeight > 0;
    if (hasRawDimensions && imageLen < static_cast<size_t>(imageWidth) * static_cast<size_t>(imageHeight) * 4)
        return;

    try
    {
        Rect appearanceRect(0.0, 0.0, rectWidth, rectHeight);
        auto appearance = document.CreateXObjectForm(appearanceRect);
        PdfPainter painter;
        painter.SetCanvas(*appearance);

        if (hasRawDimensions)
        {
            auto image = document.CreateImage();
            bufferview buffer(reinterpret_cast<const char*>(imageData), imageLen);
            image->SetData(buffer, imageWidth, imageHeight, PdfPixelFormat::RGBA);
            double scaleX = rectWidth / static_cast<double>(imageWidth);
            double scaleY = rectHeight / static_cast<double>(imageHeight);
            if (scaleX <= 0.0)
                scaleX = 1.0;
            if (scaleY <= 0.0)
                scaleY = 1.0;
            painter.DrawImage(*image, 0.0, 0.0, scaleX, scaleY);
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
            painter.DrawImage(*image, 0.0, 0.0, scaleX, scaleY);
        }

        painter.FinishDrawing();
        signature.MustGetWidget().SetAppearanceStream(*appearance);
    }
    catch (const PdfError& err)
    {
        std::fprintf(stderr, "PdfSignatureGenerator: Unable to embed signature image: %s\n", err.what());
    }
    catch (...)
    {
        std::fprintf(stderr, "PdfSignatureGenerator: Unable to embed signature image (unknown error)\n");
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
        m_pPdfDocument = std::make_unique<PdfMemDocument>();
        bufferview buffer(pdf, static_cast<size_t>(len));
        m_pPdfDocument->LoadFromBuffer(buffer);
        int nSigns = PDFVerifier::GetNumberOfSignatures(m_pPdfDocument.get());
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
    if (signatureImageData && signatureImageLen > 0)
    {
        m_signatureImage.assign(signatureImageData, signatureImageData + signatureImageLen);
        m_signatureImageWidth = width;
        m_signatureImageHeight = height;
    }
    else
    {
        m_signatureImage.clear();
        m_signatureImageWidth = 0;
        m_signatureImageHeight = 0;
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

    PdfPage& page = m_pPdfDocument->GetPages().GetPageAt(pageIndex);
    Rect cropBox = page.GetCropBox();

    const double pageLeft = cropBox.GetLeft();
    const double pageBottom = cropBox.GetBottom();
    const double left0 = pageLeft + (left * cropBox.Width);
    const double bottom0 = pageBottom + (bottom * cropBox.Height);
    const double width0 = width * cropBox.Width;
    const double height0 = height * cropBox.Height;

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
    return names;
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
            auto* signature = dynamic_cast<PdfSignature*>(field);
            if (!signature)
                continue;
            if (!fieldName.empty())
            {
                auto currentName = getFieldName(field);
                if (currentName != fieldName)
                    continue;
            }
            if (requireUnsigned && IsFieldSigned(*signature))
                continue;
            return signature;
        }
    }
    catch (const PdfError&)
    {
        return nullptr;
    }
    catch (...)
    {
        return nullptr;
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
    if (customRect)
    {
        rect = *customRect;
    }
    else
    {
        try
        {
            PdfAnnotationWidget& widget = signature.MustGetWidget();
            rect = widget.GetRect();
        }
        catch (const PdfError&)
        {
            rect = Rect();
        }
        catch (...)
        {
            rect = Rect();
        }
    }

    m_pSignatureField = &signature;
    if (!m_signatureImage.empty() && rect.Width > 0.0 && rect.Height > 0.0)
    {
        ApplyAppearanceImage(signature,
            *m_pPdfDocument,
            rect,
            m_signatureImage.data(),
            m_signatureImage.size(),
            m_signatureImageWidth,
            m_signatureImageHeight);
    }
    m_subFilter = szSubFilter && szSubFilter[0] ? szSubFilter : kDefaultSubFilter;
    return true;
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
