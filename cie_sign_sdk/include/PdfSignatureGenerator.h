/*
 *  PdfSignatureGenerator.h
 *  SignPoDoFo
 *
 *  Created by svp on 26/05/12.
 *  Copyright 2012 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef _PDFSIGNATUREGENERATOR_H_
#define _PDFSIGNATUREGENERATOR_H_

#include "podofo/podofo.h"
#include "ASN1/UUCByteArray.h"

#include <cstddef>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace PoDoFo {
class PdfSigningContext;
class PdfSignerId;
class PdfSignature;
class PdfSigner;
class StreamDevice;
}

class PdfSignatureGenerator
{
public:
	PdfSignatureGenerator();
	
	virtual ~PdfSignatureGenerator();
	
	int Load(const char* pdf, int len);
	
	void InitSignature(int pageIndex, const char* szReason, const char* szReasonLabel, const char* szName, const char* szNameLabel, const char* szLocation, const char* szLocationLabel, const char* szFieldName, const char* szSubFilter);
	
	void InitSignature(int pageIndex, float left, float bottom, float width, float height, const char* szReason, const char* szReasonLabel, const char* szName, const char* szNameLabel, const char* szLocation, const char* szLocationLabel, const char* szFieldName, const char* szSubFilter);
	
	void InitSignature(int pageIndex, float left, float bottom, float width, float height, const char* szReason, const char* szReasonLabel, const char* szName, const char* szNameLabel, const char* szLocation, const char* szLocationLabel, const char* szFieldName, const char* szSubFilter, const char* szImagePath, const char* szDescription, const char* szGraphometricData, const char* szVersion);

    bool InitExistingSignatureField(const char* szFieldName,
        const char* szReason,
        const char* szName,
        const char* szLocation,
        const char* szSubFilter);

    bool InitFirstUnsignedSignatureField(const char* szReason,
        const char* szName,
        const char* szLocation,
        const char* szSubFilter);

    std::vector<std::string> ListUnsignedSignatureFieldNames() const;
	
	void SetSignatureImage(const uint8_t* signatureImageData, size_t signatureImageLen, uint32_t width, uint32_t height);
	
	void GetBufferForSignature(UUCByteArray& toSign);
	
	void SetSignature(const char* signature, int len);
	
	void GetSignedPdf(UUCByteArray& signature);
	
	void AddFont(const char* szFontName, const char* szFontPath);
	
	const double getWidth(int pageIndex);
	
	const double getHeight(int pageIndex);
	
private:
    PoDoFo::PdfSignature* FindSignatureField(const std::string& fieldName,
        bool requireUnsigned);
    bool IsFieldSigned(const PoDoFo::PdfSignature& signature) const;
    bool PrepareSignatureField(PoDoFo::PdfSignature& signature,
        const PoDoFo::Rect* customRect,
        const char* szReason,
        const char* szName,
        const char* szLocation,
        const char* szSubFilter);
	std::unique_ptr<PoDoFo::PdfMemDocument> m_pPdfDocument;
	PoDoFo::PdfSignature* m_pSignatureField;
	std::unique_ptr<PoDoFo::PdfSigningContext> m_pSigningContext;
	std::shared_ptr<PoDoFo::PdfSigner> m_pSigner;
	std::shared_ptr<PoDoFo::StreamDevice> m_pDevice;
	PoDoFo::PdfSigningResults m_signingResults;
	std::optional<PoDoFo::PdfSignerId> m_signerId;
	std::string m_subFilter;
	int m_actualLen;
    size_t m_placeholderSize;
    std::string m_originalPdfData;
    std::string m_streamBuffer;
    std::vector<uint8_t> m_signatureImage;
    uint32_t m_signatureImageWidth;
    uint32_t m_signatureImageHeight;
	
	static bool IsSignatureField(const PoDoFo::PdfMemDocument* pDoc, const PoDoFo::PdfObject *const pObj);
};

#endif // _PDFSIGNATUREGENERATOR_H_
