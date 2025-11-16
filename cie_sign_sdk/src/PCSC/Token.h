#pragma once

#ifdef WIN32
#include <winscard.h>
#else
#if defined(__has_include)
#  if __has_include(<PCSC/winscard.h>)
#    include <PCSC/winscard.h>
#  elif __has_include(<winscard.h>)
#    include <winscard.h>
#  else
#    include "mobile/winscard_stub.h"
#  endif
#else
#  include "mobile/winscard_stub.h"
#endif
#endif

#include "APDU.h"
#include "../Util/SyncroMutex.h"

enum CardPSO {
	Op_PSO_DEC,
	Op_PSO_ENC,
	Op_PSO_CDS
};

class CToken
{
public:
	typedef HRESULT(*TokenTransmitCallback)(void *data, uint8_t *apdu, DWORD apduSize, uint8_t *resp, DWORD *respSize);

private:
	TokenTransmitCallback transmitCallback;
	void *transmitCallbackData;
public:
	CToken();
	~CToken();

	void SelectMF();
	ByteDynArray BinaryRead(WORD start,BYTE size);
	void Reset(bool unpower = false);

	void setTransmitCallback(TokenTransmitCallback func,void *data);
	void setTransmitCallbackData(void *data);
	void* getTransmitCallbackData();
	StatusWord Transmit(APDU &apdu, ByteDynArray *resp);
	StatusWord Transmit(ByteArray apdu, ByteDynArray *resp);
};
