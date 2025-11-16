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

#include <memory>
#include <optional>
#include <string>

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
	
	void GetBufferForSignature(UUCByteArray& toSign);
	
	void SetSignature(const char* signature, int len);
	
	void GetSignedPdf(UUCByteArray& signature);
	
	void AddFont(const char* szFontName, const char* szFontPath);
	
	const double getWidth(int pageIndex);
	
	const double getHeight(int pageIndex);
	
private:
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
	
	static bool IsSignatureField(const PoDoFo::PdfMemDocument* pDoc, const PoDoFo::PdfObject *const pObj);
};

#endif // _PDFSIGNATUREGENERATOR_H_
