#include "PdfSignatureGenerator.h"

#include "PdfVerifier.h"
#include "UUCLogger.h"

#include <stdexcept>
#include <vector>
#include <cstdio>

USE_LOG;

using namespace PoDoFo;

namespace {

constexpr const char* kDefaultFilter = "Adobe.PPKLite";
constexpr const char* kDefaultSubFilter = "ETSI.CAdES.detached";

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

} // namespace

PdfSignatureGenerator::PdfSignatureGenerator()
    : m_pPdfDocument(nullptr),
      m_pSignatureField(nullptr),
      m_actualLen(0),
      m_placeholderSize(0)
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

    const double left0 = left * cropBox.Width;
    const double bottom0 = cropBox.Height - (bottom * cropBox.Height);
    const double width0 = width * cropBox.Width;
    const double height0 = height * cropBox.Height;

    Rect rect(left0, bottom0, width0, height0);

    auto fieldName = std::string(szFieldName ? szFieldName : "Signature1");
    PdfSignature* signature = CreateSignatureField(*m_pPdfDocument, pageIndex, fieldName, rect);
    if (!signature)
        throw std::runtime_error("Failed to create signature field");

    if (szReason && szReason[0])
        signature->SetSignatureReason(makeString(szReason));
    if (szLocation && szLocation[0])
        signature->SetSignatureLocation(makeString(szLocation));
    if (szName && szName[0])
        signature->SetSignerName(makeString(szName));

    PdfDate now;
    signature->SetSignatureDate(now);

    m_pSignatureField = signature;
    m_subFilter = szSubFilter && szSubFilter[0] ? szSubFilter : kDefaultSubFilter;
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
