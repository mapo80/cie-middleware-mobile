/*
 *  PdfVerifier.cpp
 *  SignPoDoFo
 *
 *  Created by svp on 26/05/12.
 *  Copyright 2012 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef HP_UX

#include "PdfVerifier.h"
#include <array>
#include <cctype>
#include <cstring>
#include <string>
#include <vector>

#include "ASN1/SignedData.h"
#include "ASN1/SignerInfo.h"
#include "SignedDocument.h"

#ifdef GetObject
#undef GetObject
#endif

extern logFunc pfnCrashliticsLog;

namespace {

const PdfObject* resolveObject(const PdfMemDocument* doc, const PdfObject* obj)
{
    if (!doc || !obj)
        return obj;
    if (obj->IsReference())
        return doc->GetObjects().GetObject(obj->GetReference());
    return obj;
}

bool decodeHexString(const std::string_view& hex, UUCByteArray& out)
{
    out.removeAll();
    int hi = -1;
    for (char c : hex)
    {
        if (std::isspace(static_cast<unsigned char>(c)))
            continue;
        int val = -1;
        if (c >= '0' && c <= '9')
            val = c - '0';
        else if (c >= 'a' && c <= 'f')
            val = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F')
            val = c - 'A' + 10;
        else
            continue;
        if (hi < 0)
            hi = val;
        else
        {
            unsigned char byte = static_cast<unsigned char>((hi << 4) | val);
            out.append(&byte, 1);
            hi = -1;
        }
    }
    return hi < 0 && out.getLength() > 0;
}

bool extractContentsData(const PdfObject* obj, UUCByteArray& dest)
{
    if (!obj)
        return false;
    dest.removeAll();
    if (obj->IsString())
    {
        const PdfString& str = obj->GetString();
        auto raw = str.GetRawData();
        return decodeHexString(std::string_view(raw.data(), raw.size()), dest);
    }
    return false;
}

bool isSignatureFieldObject(const PdfMemDocument* doc, const PdfObject* obj)
{
    const PdfObject* field = resolveObject(doc, obj);
    if (!field || !field->IsDictionary())
        return false;
    const PdfObject* keyFTValue = field->GetDictionary().GetKey(PdfName("FT"));
    if (!keyFTValue)
        return false;
    std::string value;
    keyFTValue->ToString(value);
    if (value != "/Sig")
        return false;
    const PdfObject* keyVValue = field->GetDictionary().GetKey(PdfName("V"));
    if (!keyVValue)
        return false;
    const PdfObject* signature = resolveObject(doc, keyVValue);
    return signature && signature->IsDictionary();
}

bool extractByteRange(const PdfObject* obj, std::array<long long, 4>& range)
{
    if (!obj || !obj->IsArray())
        return false;
    const PdfArray& arr = obj->GetArray();
    if (arr.GetSize() != range.size())
        return false;
    for (size_t i = 0; i < range.size(); ++i)
        range[i] = arr.MustFindAt(i).GetNumberLenient();
    return true;
}

bool buildSignedContent(const std::array<long long, 4>& range,
    const char* buffer,
    size_t bufferLength,
    UUCByteArray& out)
{
    if (!buffer)
        return false;
    out.removeAll();
    for (size_t i = 0; i < range.size(); i += 2)
    {
        long long start = range[i];
        long long len = range[i + 1];
        if (start < 0 || len < 0 ||
            static_cast<unsigned long long>(start + len) > bufferLength)
            return false;
        out.append(reinterpret_cast<const BYTE*>(buffer + start),
            static_cast<unsigned int>(len));
    }
    return true;
}

bool collectSignatureFields(const PdfMemDocument* doc,
    std::vector<const PdfObject*>& fields)
{
    if (!doc)
        return false;
    const PdfObject* trailer = &doc->GetTrailer().GetObject();
    if (!trailer || !trailer->IsDictionary())
        return false;
    const PdfObject* catalogRef = trailer->GetDictionary().GetKey(PdfName("Root"));
    const PdfObject* catalog = resolveObject(doc, catalogRef);
    if (!catalog || !catalog->IsDictionary())
        return false;
    const PdfObject* acroFormValue = catalog->GetDictionary().GetKey(PdfName("AcroForm"));
    if (!acroFormValue)
        return true;
    acroFormValue = resolveObject(doc, acroFormValue);
    if (!acroFormValue || !acroFormValue->IsDictionary())
        return true;
    const PdfObject* fieldsValue = acroFormValue->GetDictionary().GetKey(PdfName("Fields"));
    if (!fieldsValue)
        return true;
    fieldsValue = resolveObject(doc, fieldsValue);
    if (!fieldsValue || !fieldsValue->IsArray())
        return true;
    const PdfArray& array = fieldsValue->GetArray();
    for (unsigned int i = 0; i < array.GetSize(); ++i)
    {
        const PdfObject& entry = array[i];
        const PdfObject* resolved = resolveObject(doc, &entry);
        if (isSignatureFieldObject(doc, resolved))
            fields.push_back(resolved);
    }
    return true;
}

} // namespace

PDFVerifier::PDFVerifier()
: m_pPdfDocument(NULL), m_actualLen(0)
{
	
}

PDFVerifier::~PDFVerifier()
{
	if(m_pPdfDocument)
		delete m_pPdfDocument;
}

int PDFVerifier::Load(const char* pdf, int len)
{
	if(m_pPdfDocument)
		delete m_pPdfDocument;
	
	try
	{
		m_pPdfDocument = new PdfMemDocument();
        m_data.removeAll();
        m_data.append(reinterpret_cast<const BYTE*>(pdf), len);
        m_actualLen = len;
        bufferview buffer(reinterpret_cast<const char*>(m_data.getContent()),
            static_cast<size_t>(m_data.getLength()));
        m_pPdfDocument->LoadFromBuffer(buffer);
        m_szDocBuffer = reinterpret_cast<const char*>(m_data.getContent());
		
		return 0;
	}
    catch(::PoDoFo::PdfError& err)
    {
        return -2;
    }
	catch (...) 
	{
		return -1;
	}
}

int PDFVerifier::Load(const char* szFilePath)
{
    if(m_pPdfDocument)
        delete m_pPdfDocument;
    
    try
    {
        m_pPdfDocument = new PdfMemDocument();
        m_pPdfDocument->Load(szFilePath);
        
        BYTE buffer[BUFFERSIZE];
        int nRead = 0;
    
        FILE* f = fopen(szFilePath, "rb");
        if(!f)
        {
            return DISIGON_ERROR_FILE_NOT_FOUND;
        }
    
        m_data.removeAll();
        
        while(((nRead = fread(buffer, 1, BUFFERSIZE, f)) > 0))
        {
            m_data.append(buffer, nRead);
        }
        
        fclose(f);
        m_actualLen = m_data.getLength();
        m_szDocBuffer = (char*)m_data.getContent();
        
        return 0;
    }
    catch(::PoDoFo::PdfError& err)
    {
        return -2;
    }
    catch (...)
    {
        return -1;
    }
}

int PDFVerifier::GetNumberOfSignatures(const char* szFilePath)
{
    pfnCrashliticsLog("PDFVerifier::GetNumberOfSignatures");
    pfnCrashliticsLog(szFilePath);
    
    PdfMemDocument doc;
    
    try {
        
        doc.Load(szFilePath);
        
        pfnCrashliticsLog("file loaded");
        
        return GetNumberOfSignatures(&doc);
    }
    catch(::PoDoFo::PdfError& err)
    {
        return -2;
    }
    catch (...) {
        return -1;
    }
    
}


int PDFVerifier::GetNumberOfSignatures(PdfMemDocument* pPdfDocument)
{
	if(!pPdfDocument)
		return -1;
    std::vector<const PdfObject*> signatureVector;
    if (!collectSignatureFields(pPdfDocument, signatureVector))
        return -1;
	return static_cast<int>(signatureVector.size());
}

int PDFVerifier::GetNumberOfSignatures()
{
	if(!m_pPdfDocument)
		return -1;
	
	return GetNumberOfSignatures(m_pPdfDocument);
		
}

int PDFVerifier::VerifySignature(int index, const char* szDate, char* signatureType, REVOCATION_INFO* pRevocationInfo)
{
	if(!m_pPdfDocument)
		return -1;
    std::vector<const PdfObject*> signatureVector;
    if (!collectSignatureFields(m_pPdfDocument, signatureVector))
        return -1;
	if(index < 0 || static_cast<size_t>(index) >= signatureVector.size())
		return 0;
	return VerifySignature(m_pPdfDocument, signatureVector[index], szDate, signatureType, pRevocationInfo);
}


int PDFVerifier::VerifySignature(const PdfMemDocument* pDoc, const PdfObject *const pObj, const char* szDate, char* signatureType, REVOCATION_INFO* pRevocationInfo)
{
	const PdfObject* field = resolveObject(pDoc, pObj);
	if (!field || !field->IsDictionary())
		return -1;
	const PdfObject* keyFTValue = field->GetDictionary().GetKey(PdfName("FT"));
	if (!keyFTValue)
		return -2;
	string value;
	keyFTValue->ToString(value);
	if (value != "/Sig")
		return -3;
	const PdfObject* keyVValue = field->GetDictionary().GetKey(PdfName("V"));
	if (!keyVValue)
		return -4;
	const PdfObject* signature = resolveObject(pDoc, keyVValue);
	if (!signature || !signature->IsDictionary())
		return -6;
	std::string subfilter;
	if (const PdfObject* keySubFilter = signature->GetDictionary().GetKey(PdfName("SubFilter")))
		keySubFilter->ToString(subfilter);
	if (signatureType)
		std::strcpy(signatureType, subfilter.c_str());
	std::array<long long, 4> byteRange{};
	const PdfObject* keyByteRange = signature->GetDictionary().GetKey(PdfName("ByteRange"));
	if (!extractByteRange(keyByteRange, byteRange))
		return -5;
	UUCByteArray cmsData;
	if (!extractContentsData(signature->GetDictionary().GetKey(PdfName("Contents")), cmsData))
		return -6;
	CSignedDocument signedDocument(cmsData.getContent(), cmsData.getLength());
	CSignedData signedData(signedDocument.getSignedData());
	if(subfilter == "/adbe.pkcs7.detached" || subfilter == "/ETSI.CAdES.detached")
	{
		UUCByteArray baContent;
		if (!buildSignedContent(byteRange, m_szDocBuffer, static_cast<size_t>(m_actualLen), baContent))
			return -5;
		CASN1SetOf signerInfos = signedData.getSignerInfos();
		CSignerInfo signerInfo(signerInfos.elementAt(0));
		CASN1SetOf certificates = signedData.getCertificates();
		CASN1OctetString actualContent(baContent);
		return CSignerInfo::verifySignature(actualContent, signerInfo, certificates, szDate, pRevocationInfo);
	}
	else if(subfilter == "/adbe.pkcs7.sha1")
	{
		return signedData.verify(0, szDate, pRevocationInfo);
	}
	return -5;
}


bool PDFVerifier::IsSignatureField(const PdfMemDocument* pDoc, const PdfObject *const pObj)
{
	return isSignatureFieldObject(pDoc, pObj);
}




int PDFVerifier::GetSignature(int index, UUCByteArray& signedDocument, SignatureAppearanceInfo& signatureInfo)
{
	if(!m_pPdfDocument)
		return -1;
    std::vector<const PdfObject*> signatureVector;
    if (!collectSignatureFields(m_pPdfDocument, signatureVector))
        return -1;
	if(index < 0 || static_cast<size_t>(index) >= signatureVector.size())
		return -8;
	return GetSignature(m_pPdfDocument, signatureVector[index], signedDocument, signatureInfo);
}


int PDFVerifier::GetSignature(const PdfMemDocument* pDoc, const PdfObject *const pObj, UUCByteArray& signedDocument, SignatureAppearanceInfo& appearanceInfo)
{
	const PdfObject* field = resolveObject(pDoc, pObj);
	if (!field || !field->IsDictionary())
		return -1;
	const PdfObject* keyRect = field->GetDictionary().GetKey(PdfName("Rect"));
	if (!keyRect)
		return -4;
	Rect rect = Rect::FromArray(keyRect->GetArray());
	appearanceInfo.left = static_cast<int>(rect.GetLeft());
	appearanceInfo.bottom = static_cast<int>(rect.GetBottom());
	appearanceInfo.width = static_cast<int>(rect.Width);
	appearanceInfo.heigth = static_cast<int>(rect.Height);
	const PdfObject* keyVValue = field->GetDictionary().GetKey(PdfName("V"));
	if (!keyVValue)
		return -4;
	const PdfObject* signature = resolveObject(pDoc, keyVValue);
	if (!signature || !signature->IsDictionary())
		return -6;
	UUCByteArray tempContents;
	if (!extractContentsData(signature->GetDictionary().GetKey(PdfName("Contents")), tempContents))
		return -6;
	signedDocument.removeAll();
	signedDocument.append(tempContents.getContent(), tempContents.getLength());
	return 0;
}



#else

#include "PdfVerifier.h"
#include <string>

#include "ASN1/SignedData.h"
#include "ASN1/SignerInfo.h"
#include "SignedDocument.h"

#ifdef GetObject
#undef GetObject
#endif

char* finds(const  char* szContent, const char* end, char* szSubstr)
{
	int substrlen = strlen(szSubstr);

	for(int i = 0; szContent + i < end; i++)
	{
		if(memcmp(szContent + i, szSubstr, substrlen) == 0)
			return (char*)(szContent + i);
	}

	return NULL;
}


PDFVerifier::PDFVerifier()
: m_nSignatureCount(0), m_actualLen(0)
{
	
}

PDFVerifier::~PDFVerifier()
{
	
}

int PDFVerifier::Load(const char* pdf, int len)
{	
	try
	{
		char line[100];
		char* szByteRange = finds(pdf, pdf + len, "ByteRange");
		while(szByteRange)
		{
			char* end = strstr(szByteRange, "]");
			strncpy(line, szByteRange + 9, end - szByteRange + 1);
			line[end - szByteRange + 1] = 0;

			char* tok = strtok(line, "[ ");
			m_signature[m_nSignatureCount].start = atoi(tok);
			
			tok = strtok(NULL, " ]");
			m_signature[m_nSignatureCount].length = atoi(tok);

			tok = strtok(NULL, " ]");
			m_signature[m_nSignatureCount].start1 = atoi(tok);

			tok = strtok(NULL, " ]");
			m_signature[m_nSignatureCount].length1 = atoi(tok);

			m_signature[m_nSignatureCount].content.append(
				(BYTE*)(pdf + m_signature[m_nSignatureCount].start + m_signature[m_nSignatureCount].length + 1),
				m_signature[m_nSignatureCount].start1 - (m_signature[m_nSignatureCount].start + m_signature[m_nSignatureCount].length) - 2);			

			m_signature[m_nSignatureCount].content.append((BYTE)0);


			m_nSignatureCount++;

			szByteRange = finds(szByteRange + 9, pdf + len, "ByteRange");
		}
		m_actualLen = len;
		m_szDocBuffer = (char*)pdf;
		
		return 0;
	}
	catch (...) 
	{
		return -1;
	}
}


int PDFVerifier::GetNumberOfSignatures()
{
	return m_nSignatureCount;	
}

int PDFVerifier::GetSignature(int index, UUCByteArray& signedDocument)
{
	UUCByteArray sigdoc((char*)m_signature[index].content.getContent());
	signedDocument.append(sigdoc);

	return 0;
}


int PDFVerifier::VerifySignature(int index, const char* szDate, char* signatureType, REVOCATION_INFO* pRevocationInfo)
{
	UUCByteArray sigdoc((char*)m_signature[index].content.getContent());
	
	CSignedDocument signedDocument(sigdoc.getContent(), sigdoc.getLength());
		
	CSignedData signedData(signedDocument.getSignedData());
		
//	strcpy(signatureType, subfilter.c_str());
		
	//if(subfilter == "/adbe.pkcs7.detached" || subfilter == "/ETSI.CAdES.detached")

	UUCByteArray baContent;
	baContent.append((BYTE*)m_szDocBuffer, m_signature[index].length);
	baContent.append(((BYTE*)m_szDocBuffer + m_signature[index].start1), m_signature[index].length1);
			
	CASN1SetOf signerInfos = signedData.getSignerInfos();
	CSignerInfo signerInfo(signerInfos.elementAt(0));
	CASN1SetOf certificates = signedData.getCertificates();
						
	CASN1OctetString actualContent(baContent);
			
	return CSignerInfo::verifySignature(actualContent, signerInfo, certificates, szDate, pRevocationInfo);

	/*}
	else if(subfilter == "/adbe.pkcs7.sha1")
		{
			//NSLog(@"sha1 %s", subfilter.c_str());
			
			return signedData.verify(0, szDate, pRevocationInfo);
			
		}
		else 
		{
			//NSLog(@"invalid subfilter: %s", subfilter.c_str());
			return -5;
		}
	*/	
		
		// DONE:
		
		// extract the contents value
		
		// if subfilter is sha1 
		// create a SignedDocument by the contents value
		// return SignedDocument.verify
		// else
		// Create a CSignedData by the contents value
		// creates the actual content by using ByteRange
		// return CSignedData.Verify (detached) passing the actual content
	//}
	//else 
	//	return -6;

		

	return 0;	
}

/*
bool PDFVerifier::IsSignatureField(const PdfMemDocument* pDoc, const PdfObject *const pObj)
{
	return true;
}
*/

/*
int PDFVerifier::GetSignature(const PdfMemDocument* pDoc, const PdfObject *const pObj, UUCByteArray& signedDocument, SignatureAppearanceInfo& appearanceInfo)
{
	/*
	if (pObj == 0) return -1;
	
	if (!pObj->IsDictionary()) 
		return -1;
	
	const PdfObject *const keyFTValue = pObj->GetDictionary().GetKey(PdfName("FT"));
	if (keyFTValue == 0) 
		return -2;
	
	string value;
	keyFTValue->ToString(value);
	if (value != "/Sig") 
		return -3;
	
	const PdfObject *const keyVValue = pObj->GetDictionary().GetKey(PdfName("V"));
	if (keyVValue == 0) 
		return -4;
	
	const PdfObject *const keyRect = pObj->GetDictionary().GetKey(PdfName("Rect"));
	if (keyRect == 0) 
	{
		return -4;
	}
	
	PdfArray rectArray = keyRect->GetArray();
	Rect rect = Rect::FromArray(rectArray);
	
	appearanceInfo.left = rect.GetLeft();
	appearanceInfo.bottom = rect.GetBottom();
	appearanceInfo.width = rect.Width;
	appearanceInfo.heigth = rect.Height;
	
	
	const PdfObject *const signature = pDoc->GetObjects().GetObject(keyVValue->GetReference());
	if (signature->IsDictionary()) 
	{
		string signdData;
				
		const PdfObject *const keyContents = signature->GetDictionary().GetKey(PdfName("Contents"));
		keyContents->ToString(signdData);
		
		const char* szSignedData = strtok((char*)signdData.c_str(), "<>");
		
		//UUCByteArray baSignedData(szSignedData);

		signedDocument.append(szSignedData);
		return 0;
	}
	else 
		return -6;
}



	return 0;
}
*/

/*
PDFVerifier::PDFVerifier()
: m_pPdfDocument(NULL), m_actualLen(0)
{
	
}

PDFVerifier::~PDFVerifier()
{
	if(m_pPdfDocument)
		delete m_pPdfDocument;
}
  
int PDFVerifier::Load(const char* pdf, int len)
{
	if(m_pPdfDocument)
		delete m_pPdfDocument;
	
	try
	{
		m_pPdfDocument = new PdfMemDocument();
		m_pPdfDocument->Load(pdf, len);
		m_actualLen = len;
		m_szDocBuffer = (char*)pdf;
		
		return 0;
	}
	catch (...) 
	{
		return -1;
	}
}

int PDFVerifier::GetNumberOfSignatures(PdfMemDocument* pPdfDocument)
{
	/// Find the document catalog dictionary
	const PdfObject *const trailer = &pPdfDocument->GetTrailer().GetObject();
	if (!trailer || !trailer->IsDictionary())
		return -1;
	
	const PdfObject *const catalogRef =	trailer->GetDictionary().GetKey(PdfName("Root"));
	if (catalogRef==0 || !catalogRef->IsReference())
		return -2;//throw std::invalid_argument("Invalid /Root entry");
	
	const PdfObject *const catalog =
	pPdfDocument->GetObjects().GetObject(catalogRef->GetReference());
	if (catalog==0 || !catalog->IsDictionary())
		return -3;//throw std::invalid_argument("Invalid or non-dictionary
	//referenced by /Root entry");
	
	/// Find the Fields array in catalog dictionary
	const PdfObject *acroFormValue = catalog->GetDictionary().GetKey(PdfName("AcroForm"));
	if (acroFormValue == 0) 
		return 0;
	
	if (acroFormValue->IsReference())
		acroFormValue = pPdfDocument->GetObjects().GetObject(acroFormValue->GetReference());
	
	if (!acroFormValue->IsDictionary()) 
		return 0;
	
	const PdfObject *fieldsValue = acroFormValue->GetDictionary().GetKey(PdfName("Fields"));
	if (fieldsValue == 0) 
		return 0;
	
	if (fieldsValue->IsReference())
		fieldsValue = pPdfDocument->GetObjects().GetObject(acroFormValue->GetReference());
	
	if (!fieldsValue->IsArray()) 
		return 0;
	
	/// Verify if each object of the array is a signature field
	int n = 0;
	const PdfArray &array = fieldsValue->GetArray();
	for (unsigned int i=0; i<array.size(); i++) 
	{
		const PdfObject *const obj = pPdfDocument->GetObjects().GetObject(array[i].GetReference());
		if (IsSignatureField(pPdfDocument, obj)) 
		{
			n++;
		}
	}
	
	return n;
}

int PDFVerifier::GetNumberOfSignatures()
{
	if(!m_pPdfDocument)
		return -1;
	
	return GetNumberOfSignatures(m_pPdfDocument);
		
}

int PDFVerifier::VerifySignature(int index, const char* szDate, char* signatureType, REVOCATION_INFO* pRevocationInfo)
{
	if(!m_pPdfDocument)
		return -1;
	
	/// Find the document catalog dictionary
	const PdfObject *const trailer = &m_pPdfDocument->GetTrailer().GetObject();
	if (!trailer || !trailer->IsDictionary())
		return -1;
	
	const PdfObject *const catalogRef =	trailer->GetDictionary().GetKey(PdfName("Root"));
	if (catalogRef==0 || !catalogRef->IsReference())
		return -2;//throw std::invalid_argument("Invalid /Root entry");
	
	const PdfObject *const catalog =
	m_pPdfDocument->GetObjects().GetObject(catalogRef->GetReference());
	if (catalog==0 || !catalog->IsDictionary())
		return -3;//throw std::invalid_argument("Invalid or non-dictionary
	//referenced by /Root entry");
	
	/// Find the Fields array in catalog dictionary
	const PdfObject *acroFormValue = catalog->GetDictionary().GetKey(PdfName("AcroForm"));
	if (acroFormValue == 0) 
		return 0;
	
	if (acroFormValue->IsReference())
		acroFormValue = m_pPdfDocument->GetObjects().GetObject(acroFormValue->GetReference());
	
	if (!acroFormValue->IsDictionary()) 
		return 0;
	
	const PdfObject *fieldsValue = acroFormValue->GetDictionary().GetKey(PdfName("Fields"));
	if (fieldsValue == 0) 
		return 0;
	
	if (fieldsValue->IsReference())
		fieldsValue = m_pPdfDocument->GetObjects().GetObject(acroFormValue->GetReference());
	
	if (!fieldsValue->IsArray()) 
		return 0;
	
	vector<const PdfObject*> signatureVector;
	
	/// Verify if each object of the array is a signature field
	const PdfArray &array = fieldsValue->GetArray();
	for (unsigned int i=0; i<array.size(); i++) 
	{
		const PdfObject * pObj = m_pPdfDocument->GetObjects().GetObject(array[i].GetReference());
		if (IsSignatureField(m_pPdfDocument, pObj)) 
		{
			signatureVector.push_back(pObj);		
		}
	}
	
	if(index >= signatureVector.size())
		return 0;
	
	const PdfObject* pSignatureObject = signatureVector[index];
	
	return VerifySignature(m_pPdfDocument, pSignatureObject, szDate, signatureType, pRevocationInfo);
}

int PDFVerifier::VerifySignature(const PdfMemDocument* pDoc, const PdfObject *const pObj, const char* szDate, char* signatureType, REVOCATION_INFO* pRevocationInfo)
{
	if (pObj == 0) return false;
	
	if (!pObj->IsDictionary()) 
		return -1;
	
	const PdfObject *const keyFTValue = pObj->GetDictionary().GetKey(PdfName("FT"));
	if (keyFTValue == 0) 
		return -2;
	
	string value;
	keyFTValue->ToString(value);
	if (value != "/Sig") 
		return -3;
	
	const PdfObject *const keyVValue = pObj->GetDictionary().GetKey(PdfName("V"));
	if (keyVValue == 0) 
		return -4;
	
	const PdfObject *const signature = pDoc->GetObjects().GetObject(keyVValue->GetReference());
	if (signature->IsDictionary()) 
	{
		string byteRange;
		string signdData;
		string subfilter;
		
		const PdfObject *const keyByteRange = signature->GetDictionary().GetKey(PdfName("ByteRange"));
		keyByteRange->ToString(byteRange);
		
		const PdfObject *const keyContents = signature->GetDictionary().GetKey(PdfName("Contents"));
		keyContents->ToString(signdData);
		
		const PdfObject *const keySubFilter = signature->GetDictionary().GetKey(PdfName("SubFilter"));
		keySubFilter->ToString(subfilter);
		
		const char* szEntry = strtok((char*)byteRange.c_str(), " []");
		
		int start	= atoi(szEntry);
		int len		= atoi(strtok(NULL, " []"));
		int start1	= atoi(strtok(NULL, " []"));
		int len1	= atoi(strtok(NULL, " []"));
		
		int fulllen = start1 + len1;
		
		//NSLog(@"content %d, %d, %d, %d, %d", start, len, start1, len1, fulllen);
		
		const char* szSignedData = strtok((char*)signdData.c_str(), "<>");
		
		UUCByteArray baSignedData(szSignedData);
		CSignedDocument signedDocument(baSignedData.getContent(), baSignedData.getLength());
		//bool b = signedDocument.isDetached();
		
		CSignedData signedData(signedDocument.getSignedData());
		
		strcpy(signatureType, subfilter.c_str());
		
		if(subfilter == "/adbe.pkcs7.detached" || subfilter == "/ETSI.CAdES.detached")
		{
			//NSLog(@"detached %s", subfilter.c_str());
			
			// extract the actual content
						
			UUCByteArray baContent;
			baContent.append((BYTE*)m_szDocBuffer, len);
			baContent.append(((BYTE*)m_szDocBuffer + start1), len1);
			//NSLog(@"content %s", baContent.toHexString());
					
			
			//NSLog(@"content %d, %d, %d, %d, %d, %d", baContent.getLength(), start, len, start1, len1, fulllen);
			
			
			CASN1SetOf signerInfos = signedData.getSignerInfos();
			CSignerInfo signerInfo(signerInfos.elementAt(0));
			CASN1SetOf certificates = signedData.getCertificates();
			
			//NSLog(@"content %s", baContent.toHexString());
			
			CASN1OctetString actualContent(baContent);
			
			return CSignerInfo::verifySignature(actualContent, signerInfo, certificates, szDate, pRevocationInfo);
		}
		else if(subfilter == "/adbe.pkcs7.sha1")
		{
			//NSLog(@"sha1 %s", subfilter.c_str());
			
			return signedData.verify(0, szDate, pRevocationInfo);
			
		}
		else 
		{
			//NSLog(@"invalid subfilter: %s", subfilter.c_str());
			return -5;
		}
		
		
		// DONE:
		
		// extract the contents value
		
		// if subfilter is sha1 
		// create a SignedDocument by the contents value
		// return SignedDocument.verify
		// else
		// Create a CSignedData by the contents value
		// creates the actual content by using ByteRange
		// return CSignedData.Verify (detached) passing the actual content
	}
	else 
		return -6;
}


bool PDFVerifier::IsSignatureField(const PdfMemDocument* pDoc, const PdfObject *const pObj)
{
	if (pObj == 0) return false;

	if (!pObj->IsDictionary()) 
		return false;
	
	const PdfObject *const keyFTValue = pObj->GetDictionary().GetKey(PdfName("FT"));
	if (keyFTValue == 0) 
		return false;
	
	string value;
	keyFTValue->ToString(value);
	if (value != "/Sig") 
		return false;
	
	const PdfObject *const keyVValue = pObj->GetDictionary().GetKey(PdfName("V"));
	if (keyVValue == 0) 
		return false;
	
	const PdfObject *const signature = pDoc->GetObjects().GetObject(keyVValue->GetReference());
	if (signature->IsDictionary()) 
		return true;
	else 
		return false;
}


int PDFVerifier::GetSignature(int index, UUCByteArray& signedDocument, SignatureAppearanceInfo& signatureInfo)
{
	if(!m_pPdfDocument)
		return -1;
	
	/// Find the document catalog dictionary
	const PdfObject *const trailer = &m_pPdfDocument->GetTrailer().GetObject();
	if (!trailer || !trailer->IsDictionary())
		return -1;
	
	const PdfObject *const catalogRef =	trailer->GetDictionary().GetKey(PdfName("Root"));
	if (catalogRef==0 || !catalogRef->IsReference())
		return -2;//throw std::invalid_argument("Invalid /Root entry");
	
	const PdfObject *const catalog =
	m_pPdfDocument->GetObjects().GetObject(catalogRef->GetReference());
	if (catalog==0 || !catalog->IsDictionary())
		return -3;//throw std::invalid_argument("Invalid or non-dictionary
	//referenced by /Root entry");
	
	/// Find the Fields array in catalog dictionary
	const PdfObject *acroFormValue = catalog->GetDictionary().GetKey(PdfName("AcroForm"));
	if (acroFormValue == 0) 
		return -4;
	
	if (acroFormValue->IsReference())
		acroFormValue = m_pPdfDocument->GetObjects().GetObject(acroFormValue->GetReference());
	
	if (!acroFormValue->IsDictionary()) 
		return -5;
	
	const PdfObject *fieldsValue = acroFormValue->GetDictionary().GetKey(PdfName("Fields"));
	if (fieldsValue == 0) 
		return -6;
	
	if (fieldsValue->IsReference())
		fieldsValue = m_pPdfDocument->GetObjects().GetObject(acroFormValue->GetReference());
	
	if (!fieldsValue->IsArray()) 
		return -7;
	
	vector<const PdfObject*> signatureVector;
	
	/// Verify if each object of the array is a signature field
	const PdfArray &array = fieldsValue->GetArray();
	for (unsigned int i=0; i<array.size(); i++) 
	{
		const PdfObject * pObj = m_pPdfDocument->GetObjects().GetObject(array[i].GetReference());
		if (IsSignatureField(m_pPdfDocument, pObj)) 
		{
			signatureVector.push_back(pObj);
		}
	}
	
	if(index >= signatureVector.size())
		return -8;
	
	const PdfObject* pSignatureObject = signatureVector[index];
	
	return GetSignature(m_pPdfDocument, pSignatureObject, signedDocument, signatureInfo);
}

int PDFVerifier::GetSignature(const PdfMemDocument* pDoc, const PdfObject *const pObj, UUCByteArray& signedDocument, SignatureAppearanceInfo& appearanceInfo)
{
	if (pObj == 0) return -1;
	
	if (!pObj->IsDictionary()) 
		return -1;
	
	const PdfObject *const keyFTValue = pObj->GetDictionary().GetKey(PdfName("FT"));
	if (keyFTValue == 0) 
		return -2;
	
	string value;
	keyFTValue->ToString(value);
	if (value != "/Sig") 
		return -3;
	
	const PdfObject *const keyVValue = pObj->GetDictionary().GetKey(PdfName("V"));
	if (keyVValue == 0) 
		return -4;
	
	const PdfObject *const keyRect = pObj->GetDictionary().GetKey(PdfName("Rect"));
	if (keyRect == 0) 
	{
		return -4;
	}
	
	PdfArray rectArray = keyRect->GetArray();
	Rect rect = Rect::FromArray(rectArray);
	
	appearanceInfo.left = rect.GetLeft();
	appearanceInfo.bottom = rect.GetBottom();
	appearanceInfo.width = rect.Width;
	appearanceInfo.heigth = rect.Height;
	
	
	const PdfObject *const signature = pDoc->GetObjects().GetObject(keyVValue->GetReference());
	if (signature->IsDictionary()) 
	{
		string signdData;
				
		const PdfObject *const keyContents = signature->GetDictionary().GetKey(PdfName("Contents"));
		keyContents->ToString(signdData);
		
		const char* szSignedData = strtok((char*)signdData.c_str(), "<>");
		
		//UUCByteArray baSignedData(szSignedData);

		signedDocument.append(szSignedData);

		return 0;
	}
	else 
		return -6;
}

*/

#endif
