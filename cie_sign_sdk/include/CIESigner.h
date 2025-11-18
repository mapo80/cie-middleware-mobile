#pragma once


#include <string>
#include "Certificate.h"
#include "BaseSigner.h"
#include "RSAPrivateKey.h"
#include "IAS.h"

class CCIESigner : public CBaseSigner
{
public:
	CCIESigner(IAS* pIAS);
	virtual ~CCIESigner(void);

	long Init(const char* szPIN);

	virtual long GetCertificate(const char* alias, CCertificate** ppCertificate, UUCByteArray& id);

	virtual long Sign(UUCByteArray& data, UUCByteArray& id, int algo, UUCByteArray& signature);

	virtual long Close();

    typedef void (*LoggerFn)(const char* message, void* user_data);
    void SetLogger(LoggerFn fn, void* user_data);

private:
    void Log(const std::string& message);
    IAS* m_pIAS;
    char m_szPIN[9];
	CCertificate*   m_pCertificate;
    LoggerFn m_loggerFn = nullptr;
    void* m_loggerUser = nullptr;
};
