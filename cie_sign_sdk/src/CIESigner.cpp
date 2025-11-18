
#include "CIESigner.h"
#include <stdlib.h>
#include <string.h>
#include <string>
#include <cstdio>

#ifdef WIN32
#include "pkcs11.h"
/*
#pragma pack(push, cryptoki, 1)
#include "pkcs11.h"
#pragma pack(pop, cryptoki)
*/
#else
#include "cryptoki.h"
#endif

#include "UUCLogger.h"
USE_LOG;
#include <stdlib.h>
#include <openssl/obj_mac.h>

extern "C" {
void makeDigestInfo(int algid, unsigned char* pbtDigest, size_t btDigestLen, unsigned char* pbtDigestInfo, size_t* pbtDigestInfoLen);
}

namespace {
std::string format_status(long sw) {
	char buffer[16];
	std::snprintf(buffer, sizeof(buffer), "0x%04lX", sw & 0xFFFF);
	return std::string(buffer);
}
}

CCIESigner::CCIESigner(IAS* pIAS)
: m_pIAS(pIAS), m_pCertificate(NULL)
{
}

CCIESigner::~CCIESigner(void)
{
	if (m_pCertificate)
		delete m_pCertificate;
}

void CCIESigner::SetLogger(LoggerFn fn, void* user_data)
{
	m_loggerFn = fn;
	m_loggerUser = user_data;
}

void CCIESigner::Log(const std::string& message)
{
	if (m_loggerFn) {
		m_loggerFn(message.c_str(), m_loggerUser);
	}
}

long CCIESigner::Init(const char* szPIN)
{
    strcpy(m_szPIN, szPIN);
    
    LOG_DBG((0, "Init CIESigner\n", ""));
    Log("CCIESigner::Init - start");
    
    try
    {
        Log("SelectAID_IAS");
        m_pIAS->SelectAID_IAS();
        Log("SelectAID_CIE");
        m_pIAS->SelectAID_CIE();
        Log("InitDHParam");
        m_pIAS->InitDHParam();
        
//        ByteDynArray IdServizi;
//        m_pIAS->ReadIdServizi(IdServizi);
        
        ByteDynArray data;
        Log("ReadDappPubKey");
        m_pIAS->ReadDappPubKey(data);
        Log("InitExtAuthKeyParam");
        m_pIAS->InitExtAuthKeyParam();
        Log("DHKeyExchange");
        m_pIAS->DHKeyExchange();
        Log("DAPP");
        m_pIAS->DAPP();
        
        ByteArray baPIN((BYTE*)szPIN, (size_t)strlen(szPIN));
        StatusWord sw = m_pIAS->VerifyPIN(baPIN);
        
        if(sw != 0x9000)
        {
            LOG_DBG((0, "<-- CCIESigner::Init", "VerifyPIN failed: %x", sw));
            Log(std::string("VerifyPIN failed with ") + format_status(sw));
            printf("Init CIESigner OK\n");
            return sw;
        }
    
        LOG_DBG((0, "<-- CCIESigner::Init", "OK"));
        Log("VerifyPIN succeeded");
        
        return 0;
    }
    catch (scard_error err)
    {
        LOG_ERR((0, "<-- CCIESigner::Init", "failed: %x", err.sw));
        Log(std::string("IAS exception: ") + format_status(err.sw));

        return err.sw;
    }
    catch (scard_error* err)
    {
        LOG_ERR((0, "<-- CCIESigner::Init", "failed*: %x", err->sw));
        Log(std::string("IAS exception*: ") + format_status(err->sw));

        return err->sw;
    }
    catch(...)
    {
        LOG_ERR((0, "<-- CCIESigner::Init", "unexpected failure"));
        Log("IAS exception: unexpected failure");
        return -1;
    }
	
	return 0;
}

long CCIESigner::GetCertificate(const char* szAlias, CCertificate** ppCertificate, UUCByteArray& id)
{
	id.append((BYTE)'1');

    LOG_DBG((0, "--> CCIESigner::GetCertificate", "Alias: %s", szAlias));
    
    ByteDynArray c;
    m_pIAS->ReadCertCIE(c);
    
    *ppCertificate = new CCertificate(c.data(), c.size());
    
    LOG_DBG((0, "<-- CCIESigner::GetCertificate", "OK"));
    
    
	return CKR_OK;
}

long CCIESigner::Sign(UUCByteArray& data, UUCByteArray& id, int algo, UUCByteArray& signature)
{
	LOG_DBG((0, "--> CCIESigner::Sign", "algo: %d", algo));

    // DigestInfo
    unsigned char digestinfo[256];
    size_t digestinfolen = 256;
        
    try
    {
        // TODO digest info
        switch(algo)
        {
            case CKM_SHA256_RSA_PKCS:
                makeDigestInfo(NID_sha256, (unsigned char*)data.getContent(), (size_t)data.getLength(), (unsigned char*)digestinfo, &digestinfolen);
                
                break;
                
            case CKM_SHA1_RSA_PKCS:
                makeDigestInfo(NID_sha1, (unsigned char*)data.getContent(), (size_t)data.getLength(), (unsigned char*)digestinfo, &digestinfolen);
                break;
                
            case CKM_RSA_PKCS:
                digestinfolen = data.getLength();
                memcpy(digestinfo, data.getContent(), digestinfolen);
                break;
        }
        
        ByteArray baDigestInfo(digestinfo, digestinfolen);
        ByteDynArray baSignature;
        
        m_pIAS->Sign(baDigestInfo, baSignature);
        
        signature.append(baSignature.data(), (int)baSignature.size());
	}
    catch (scard_error err)
    {
        return err.sw;
    }
	catch (...)
	{
		return -1;
	}

	return CKR_OK;
}

long CCIESigner::Close()
{
	return 0;
}
