
#include "sha256.h"

//static char *szCompiledFile=__FILE__;

#ifdef WIN32

class init_sha256 {
public:
	BCRYPT_ALG_HANDLE algo;
	init_sha256() {
		if (BCryptOpenAlgorithmProvider(&algo, BCRYPT_SHA256_ALGORITHM, MS_PRIMITIVE_PROVIDER, 0) != 0)
			throw logged_error("Errore nell'inizializzazione dell'algoritmo SHA256");
	}
	~init_sha256() {
		BCryptCloseAlgorithmProvider(algo, 0);
	}
} algo_sha256;

ByteDynArray CSHA256::Digest(ByteArray &data)
{
	BCRYPT_HASH_HANDLE hash;
	if (BCryptCreateHash(algo_sha256.algo, &hash, nullptr, 0, nullptr, 0, 0) != 0)
		throw logged_error("Errore nella creazione dell'hash SHA256");
	ByteDynArray resp(SHA256_DIGEST_LENGTH);
	if (BCryptHashData(hash, data.data(), (ULONG)data.size(), 0) != 0)
		throw logged_error("Errore nell'hash dei dati SHA256");
	if (BCryptFinishHash(hash, resp.data(), (ULONG)resp.size(), 0) != 0)
		throw logged_error("Errore nel calcolo dell'hash SHA256");
	BCryptDestroyHash(hash);

	return resp;
}

#else

#include <openssl/sha.h>

void CSHA256::Init() {
    SHA256_Init(&ctx);
    isInit = true;
}

void CSHA256::Update(ByteArray data) {
    if (!isInit)
        throw logged_error("Hash non inizializzato");
    if (data.size() > 0) {
        SHA256_Update(&ctx, data.data(), data.size());
    }
}

ByteDynArray CSHA256::Final() {
    if (!isInit)
        throw logged_error("Hash non inizializzato");
    ByteDynArray resp(SHA256_DIGEST_LENGTH);
    SHA256_Final(resp.data(), &ctx);
    isInit = false;
    return resp;
}

ByteDynArray CSHA256::Digest(ByteArray &data)
{
    SHA256_CTX localCtx;
    SHA256_Init(&localCtx);
    if (data.size() > 0) {
        SHA256_Update(&localCtx, data.data(), data.size());
    }
    ByteDynArray resp(SHA256_DIGEST_LENGTH);
    SHA256_Final(resp.data(), &localCtx);
    return resp;
}
#endif
