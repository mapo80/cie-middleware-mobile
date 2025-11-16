#pragma once

#include <stdint.h>

#ifndef SCARDCONTEXT
typedef uint32_t SCARDCONTEXT;
#endif
#ifndef SCARDHANDLE
typedef uint32_t SCARDHANDLE;
#endif
#ifndef DWORD
typedef uint32_t DWORD;
#endif
#ifndef LONG
typedef int32_t LONG;
#endif

#ifndef SCARD_S_SUCCESS
#define SCARD_S_SUCCESS 0x00000000
#endif

#ifndef SCARD_F_INTERNAL_ERROR
#define SCARD_F_INTERNAL_ERROR 0x80100001
#endif

#ifndef SCARD_E_CANCELLED
#define SCARD_E_CANCELLED 0x80100002
#endif
