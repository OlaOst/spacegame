module dbghelp;

version (Windows){

import std.c.windows.windows;
import core.runtime;
	
class Dbghelp {
public:
	typedef char TCHAR;
	typedef ulong DWORD64;
	typedef char* CTSTR;
	typedef char* PTSTR;
	typedef const(char)* PCSTR;
	
	enum ADDRESS_MODE : DWORD {
		AddrMode1616 = 0,
		AddrMode1632 = 1,
		AddrModeReal = 2,
		AddrModeFlat = 3
	};
	
	enum : DWORD {
		SYMOPT_FAIL_CRITICAL_ERRORS = 0x00000200,
		SYMOPT_LOAD_LINES = 0x00000010
	};
	
	struct GUID {
		uint Data1;
		ushort Data2;
		ushort Data3;
		ubyte[8] Data4;
	};
	
	struct ADDRESS64 {
		DWORD64 Offset;
		WORD Segment;
		ADDRESS_MODE Mode;
	};
	
	struct KDHELP64 {
		DWORD64 Thread;
		DWORD ThCallbackStack;
		DWORD ThCallbackBStore;
		DWORD NextCallback;
		DWORD FramePointer;
		DWORD64 KiCallUserMode;
		DWORD64 KeUserCallbackDispatcher;
		DWORD64 SystemRangeStart;
		DWORD64 KiUserExceptionDispatcher;
		DWORD64[7] Reserved;
	};
	
	struct STACKFRAME64 {
		ADDRESS64 AddrPC;
		ADDRESS64 AddrReturn;
		ADDRESS64 AddrFrame;
		ADDRESS64 AddrStack;
		ADDRESS64 AddrBStore;
		PVOID FuncTableEntry;
		DWORD64[4] Params;
		BOOL Far;
		BOOL Virtual;
		DWORD64[3] Reserved;
		KDHELP64 KdHelp;
	};
	
	enum : DWORD {
		IMAGE_FILE_MACHINE_I386 = 0x014c,
		IMGAE_FILE_MACHINE_IA64 = 0x0200,
		IMAGE_FILE_MACHINE_AMD64 = 0x8664
	};
	
	struct IMAGEHLP_LINE64 {
		DWORD SizeOfStruct;
		PVOID Key;
		DWORD LineNumber;
		PTSTR FileName;
		DWORD64 Address;
	};
	
	enum SYM_TYPE : int {
	    SymNone = 0,
	    SymCoff,
	    SymCv,
	    SymPdb,
	    SymExport,
	    SymDeferred,
	    SymSym,
	    SymDia,
	    SymVirtual,
	    NumSymTypes
	};
	
	struct IMAGEHLP_MODULE64 {
		DWORD SizeOfStruct;
		DWORD64 BaseOfImage;
		DWORD ImageSize;
		DWORD TimeDateStamp;
		DWORD CheckSum;
		DWORD NumSyms;
		SYM_TYPE SymType;
		TCHAR[32] ModuleName;
		TCHAR[256] ImageName;
		TCHAR[256] LoadedImageName;
		TCHAR[256] LoadedPdbName;
		DWORD CVSig;
		TCHAR[MAX_PATH*3] CVData;
		DWORD PdbSig;
		GUID PdbSig70;
		DWORD PdbAge;
		BOOL PdbUnmatched;
		BOOL DbgUnmachted;
		BOOL LineNumbers;
		BOOL GlobalSymbols;
		BOOL TypeInfo;
		BOOL SourceIndexed;
		BOOL Publics;
	};
	
	struct IMAGEHLP_SYMBOL64 {
		DWORD SizeOfStruct;
		DWORD64 Address;
		DWORD Size;
		DWORD Flags;
		DWORD MaxNameLength;
		TCHAR[1] Name;
	};
	
	extern(System){
		typedef BOOL function(HANDLE hProcess, DWORD64 lpBaseAddress, PVOID lpBuffer, DWORD nSize, LPDWORD lpNumberOfBytesRead) ReadProcessMemoryProc64;
		typedef PVOID function(HANDLE hProcess, DWORD64 AddrBase) FunctionTableAccessProc64;
		typedef DWORD64 function(HANDLE hProcess, DWORD64 Address) GetModuleBaseProc64;
		typedef DWORD64 function(HANDLE hProcess, HANDLE hThread, ADDRESS64 *lpaddr) TranslateAddressProc64;
		
		typedef BOOL function(HANDLE hProcess, PCSTR UserSearchPath, bool fInvadeProcess) SymInitializeFunc;
		typedef BOOL function(HANDLE hProcess) SymCleanupFunc;
		typedef DWORD function(DWORD SymOptions) SymSetOptionsFunc;
		typedef DWORD function() SymGetOptionsFunc;
		typedef PVOID function(HANDLE hProcess, DWORD64 AddrBase) SymFunctionTableAccess64Func;
		typedef BOOL function(DWORD MachineType, HANDLE hProcess, HANDLE hThread, STACKFRAME64 *StackFrame, PVOID ContextRecord, 
		                      ReadProcessMemoryProc64 ReadMemoryRoutine, FunctionTableAccessProc64 FunctoinTableAccess,
		                      GetModuleBaseProc64 GetModuleBaseRoutine, TranslateAddressProc64 TranslateAddress) StackWalk64Func;
		typedef BOOL function(HANDLE hProcess, DWORD64 dwAddr, PDWORD pdwDisplacement, IMAGEHLP_LINE64 *line) SymGetLineFromAddr64Func;
		typedef DWORD64 function(HANDLE hProcess, DWORD64 dwAddr) SymGetModuleBase64Func;
		typedef BOOL function(HANDLE hProcess, DWORD64 dwAddr, IMAGEHLP_MODULE64 *ModuleInfo) SymGetModuleInfo64Func;
		typedef BOOL function(HANDLE hProcess, DWORD64 Address, DWORD64 *Displacement, IMAGEHLP_SYMBOL64 *Symbol) SymGetSymFromAddr64Func;
		typedef DWORD function(CTSTR *DecoratedName, PTSTR UnDecoratedName, DWORD UndecoratedLength, DWORD Flags) UnDecorateSymbolNameFunc;
		typedef DWORD64 function(HANDLE hProcess, HANDLE hFile, PCSTR ImageName, PCSTR ModuleName, DWORD64 BaseOfDll, DWORD SizeOfDll) SymLoadModule64Func;
		typedef BOOL function(HANDLE HProcess, PTSTR SearchPath, DWORD SearchPathLength) SymGetSearchPathFunc;
		typedef BOOL function(HANDLE hProcess, DWORD64 Address) SymUnloadModule64Func;
	}
	
	private static bool isInit = false;
	private static HANDLE dbghelp_lib = cast(HANDLE)null;
	static SymInitializeFunc SymInitialize;
	static SymCleanupFunc SymCleanup;
	static StackWalk64Func StackWalk64;
	static SymGetOptionsFunc SymGetOptions;
	static SymSetOptionsFunc SymSetOptions;
	static SymFunctionTableAccess64Func SymFunctionTableAccess64;
	static SymGetLineFromAddr64Func SymGetLineFromAddr64;
	static SymGetModuleBase64Func SymGetModuleBase64;
	static SymGetModuleInfo64Func SymGetModuleInfo64;
	static SymGetSymFromAddr64Func SymGetSymFromAddr64;
	static UnDecorateSymbolNameFunc UnDecorateSymbolName;
	static SymLoadModule64Func SymLoadModule64;
	static SymGetSearchPathFunc SymGetSearchPath;
	static SymUnloadModule64Func SymUnloadModule64;
	
	static bool Init(){
		if(isInit)
			return true;
		
		dbghelp_lib = cast(HANDLE)Runtime.loadLibrary("dbghelp.dll");
		if(dbghelp_lib == null)
			return false;
		
		SymInitialize = cast(SymInitializeFunc) GetProcAddress(dbghelp_lib,"SymInitialize");
		SymCleanup = cast(SymCleanupFunc) GetProcAddress(dbghelp_lib,"SymCleanup");
		StackWalk64 = cast(StackWalk64Func) GetProcAddress(dbghelp_lib,"StackWalk64");
		SymGetOptions = cast(SymGetOptionsFunc) GetProcAddress(dbghelp_lib,"SymGetOptions");
		SymSetOptions = cast(SymSetOptionsFunc) GetProcAddress(dbghelp_lib,"SymSetOptions");
		SymFunctionTableAccess64 = cast(SymFunctionTableAccess64Func) GetProcAddress(dbghelp_lib,"SymFunctionTableAccess64");
		SymGetLineFromAddr64 = cast(SymGetLineFromAddr64Func) GetProcAddress(dbghelp_lib,"SymGetLineFromAddr64");
		SymGetModuleBase64 = cast(SymGetModuleBase64Func) GetProcAddress(dbghelp_lib,"SymGetModuleBase64");
		SymGetModuleInfo64 = cast(SymGetModuleInfo64Func) GetProcAddress(dbghelp_lib,"SymGetModuleInfo64");
		SymGetSymFromAddr64 = cast(SymGetSymFromAddr64Func) GetProcAddress(dbghelp_lib,"SymGetSymFromAddr64");
		SymLoadModule64 = cast(SymLoadModule64Func) GetProcAddress(dbghelp_lib,"SymLoadModule64");
		SymGetSearchPath = cast(SymGetSearchPathFunc) GetProcAddress(dbghelp_lib,"SymGetSearchPath");
		SymUnloadModule64 = cast(SymUnloadModule64Func) GetProcAddress(dbghelp_lib,"SymUnloadModule64");
		
		if(!SymInitialize || !SymCleanup || !StackWalk64 || !SymGetOptions || !SymSetOptions || !SymFunctionTableAccess64
		   || !SymGetLineFromAddr64 || !SymGetModuleBase64 || !SymGetModuleInfo64 || !SymGetSymFromAddr64
		   || !SymLoadModule64 || !SymGetSearchPath || !SymUnloadModule64){
			return false;
		}
		
		isInit = true;
		return true;
	
	}
	
	void DeInit(){
		if(isInit){
			Runtime.unloadLibrary(dbghelp_lib);
			isInit = false;
		}
	}
};
	
}