
#include "funccallinfo.h"
#include <stdio.h>

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

// iOS static library linking has issues with thread_local variables (dyld: missing symbol)
#if defined(__APPLE__) && TARGET_OS_IOS
static size_t tlsCallDepth = 0;
static std::unique_ptr<CFuncCallInfoList> callQueue = nullptr;
#else
thread_local size_t tlsCallDepth = 0;
thread_local std::unique_ptr<CFuncCallInfoList> callQueue = nullptr;
#endif
extern bool FunctionLog;
extern unsigned int GlobalDepth;
extern bool GlobalParam;
char szEmpty[]={'\0'};

CFuncCallInfo::CFuncCallInfo(const char *name, CLog &logInfo) : log(logInfo) {
	fName = name;
	//OutputDebugString(fName);
	if (FunctionLog) {
		if (tlsCallDepth < GlobalDepth) {
			LogNum = logInfo.write("%*sIN -> %s", (DWORD)tlsCallDepth, szEmpty, fName);
		}
	}

	//fName = name;
	tlsCallDepth = tlsCallDepth + 1;


//	auto head = callQueue.release();
//	callQueue = std::unique_ptr<CFuncCallInfoList>(new CFuncCallInfoList(this));
//	callQueue->next = std::unique_ptr<CFuncCallInfoList>(head);
}

CFuncCallInfo::~CFuncCallInfo() {
	//OutputDebugString(stdPrintf("OUT %s", fName).c_str());
	//fName = NULL;
	tlsCallDepth=tlsCallDepth-1;
	if (fName)
		log.write("%*sOUT -> %s (%u)",(DWORD)tlsCallDepth,szEmpty,fName,LogNum-1);

//	if (callQueue!=nullptr && callQueue->info == this) {
//		//auto head = callQueue->next.release();
////		callQueue = std::unique_ptr<CFuncCallInfoList>(head);
//	}
//	else {
//		callQueue = nullptr;
//		OutputDebugString("Errore nella sequenza delle funzioni");
//	}
}

const char *CFuncCallInfo::FunctionName() {
	return fName;
}
