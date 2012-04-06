module stacktrace;

version(Windows){

import std.c.windows.windows;
import std.c.string;
import std.string;
import dbghelp;
import core.runtime;
import std.stdio;
import std.c.stdlib;
import std.demangle;
import std.conv;

extern(Windows){
	DWORD GetEnvironmentVariableA(LPCSTR lpName, LPSTR pBuffer, DWORD nSize);
	void RtlCaptureContext(CONTEXT* ContextRecord);
	typedef LONG function(void*) UnhandeledExceptionFilterFunc;
	void* SetUnhandledExceptionFilter(void* handler);
}

class StackTrace {
private:
	enum : uint {
		MAX_MODULE_NAME32 = 255,
		TH32CS_SNAPMODULE = 0x00000008,
		MAX_NAMELEN = 1024
	};
	
	struct MODULEENTRY32 {
		DWORD dwSize;
		DWORD th32ModuleID;
		DWORD th32ProcessID;
		DWORD GlblcntUsage;
		DWORD ProccntUsage;
		BYTE* modBaseAddr;
		DWORD modBaseSize;
		HMODULE hModule;
		CHAR[MAX_MODULE_NAME32 + 1] szModule;
		CHAR[MAX_PATH] szExePath;
	};
	
	string m_UserSymPath;
	static bool isInit = false;
	static bool modulesLoaded = false;
	
	extern(System){
		typedef HANDLE function(DWORD dwFlags, DWORD th32ProcessID) CreateToolhelp32SnapshotFunc;
		typedef BOOL function(HANDLE hSnapshot, MODULEENTRY32 *lpme) Module32FirstFunc;
		typedef BOOL function(HANDLE hSnapshot, MODULEENTRY32 *lpme) Module32NextFunc;
	}
	
	extern(Windows) static LONG UnhandeledExceptionFilterHandler(void* info){
		printStackTrace();
		return 0;
	}
	
	static void printStackTrace(){
		auto stack = TraceHandler(null);
		foreach(char[] s;stack){
			writefln("%s",s);
		}
	}
	
	bool LoadModules(HANDLE hProcess, DWORD pid){
		if(modulesLoaded)
			return true;
		
		CreateToolhelp32SnapshotFunc CreateToolhelp32Snapshot = null;
		Module32FirstFunc Module32First = null;
		Module32NextFunc Module32Next = null;
			
		HMODULE hDll = null;
		
		string[] searchDlls = [ "kernel32.dll", "tlhelp32.dll" ];
		foreach(dll;searchDlls){
			hDll = cast(HMODULE)Runtime.loadLibrary(dll);
			if(hDll == null)
				break;
			CreateToolhelp32Snapshot = cast(CreateToolhelp32SnapshotFunc) GetProcAddress(hDll,"CreateToolhelp32Snapshot");
			Module32First = cast(Module32FirstFunc) GetProcAddress(hDll,"Module32First");
			Module32Next = cast(Module32NextFunc) GetProcAddress(hDll,"Module32Next");
			if(CreateToolhelp32Snapshot != null && Module32First != null && Module32Next != null)
				break;
			Runtime.unloadLibrary(hDll);
			hDll = null;
		}
		
		if(hDll == null){
			return false;
		}
		
		HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, pid);
		if(hSnap == cast(HANDLE) -1)
			return false;
		
		MODULEENTRY32 ModuleEntry;
		memset(&ModuleEntry,0,MODULEENTRY32.sizeof);
		ModuleEntry.dwSize = MODULEENTRY32.sizeof;
		
		bool more = cast(bool)Module32First(hSnap,&ModuleEntry);
		int count = 0;
		while(more){
			LoadModule(hProcess, ModuleEntry.szExePath.ptr, ModuleEntry.szModule.ptr, cast(Dbghelp.DWORD64)ModuleEntry.modBaseAddr, ModuleEntry.modBaseSize);
			count++;
			more = cast(bool)Module32Next(hSnap,&ModuleEntry);
		}
		
		CloseHandle(hSnap);
		Runtime.unloadLibrary(hDll);
		
		if(count <= 0)
			return false;
		
		modulesLoaded = true;
		return true;
	}

	void LoadModule(HANDLE hProcess, LPCSTR img, LPCSTR mod, Dbghelp.DWORD64 baseAddr, DWORD size){
		char[] szImg = new char[strlen(img)];
		char[] szMod = new char[strlen(mod)];
		szImg[0..szImg.length] = img[0..(strlen(img))];
		szMod[0..szMod.length] = mod[0..(strlen(mod))];
		
		Dbghelp.DWORD64 moduleAddr = Dbghelp.SymLoadModule64(hProcess,HANDLE.init,cast(Dbghelp.PCSTR)toStringz(szImg),cast(Dbghelp.PCSTR)toStringz(szMod),baseAddr,size);
		if(moduleAddr == 0)
			return;
		
		Dbghelp.IMAGEHLP_MODULE64 ModuleInfo;
		memset(&ModuleInfo,0,typeof(ModuleInfo).sizeof);
		ModuleInfo.SizeOfStruct = typeof(ModuleInfo).sizeof;
		if(Dbghelp.SymGetModuleInfo64(hProcess,moduleAddr,&ModuleInfo) == TRUE){
			if(ModuleInfo.SymType == Dbghelp.SYM_TYPE.SymNone){
				Dbghelp.SymUnloadModule64(hProcess,moduleAddr);
				moduleAddr = Dbghelp.SymLoadModule64(hProcess,HANDLE.init,cast(Dbghelp.PCSTR)toStringz(szImg),null,cast(Dbghelp.DWORD64)0,0);
				if(moduleAddr == 0)
					return;
			}
		}
		
		//writefln("Successfully loaded module %s",szImg);
	}
	
	string GenereateSearchPath(){
		string path;
		if(m_UserSymPath.length){
			path = m_UserSymPath ~ ";";
		}
		
		char[1024] temp;
		if(GetCurrentDirectoryA(temp.length,temp.ptr) > 0){
			temp[temp.length-1] = 0;
			path ~= temp ~ ";";
		}
		
		if(GetModuleFileNameA(null,temp.ptr,temp.length) > 0){
			temp[temp.length-1] = 0;
			foreach_reverse(ref char e;temp){
				if(e == '\\' || e == '/' || e == ':'){
					e = 0;
					break;
				}
			}
			if(strlen(temp.ptr) > 0){
				path ~= temp ~ ";";
			}
		}
		
		string[] systemVars = [ "_NT_SYMBOL_PATH", "_NT_ALTERNATE_SYMBOL_PATH", "SYSTEMROOT" ];
		
		foreach(e;systemVars){
			if(GetEnvironmentVariableA(toStringz(e),temp.ptr,temp.length) > 0){
				temp[temp.length-1] = 0;
				path ~= temp ~ ";";
			}
		}
		
		return path;
	}
	
	static class Callstack : Throwable.TraceInfo {
	private:
		string[] info = null;
	public:		
		int opApply(scope int delegate(ref char[]) dg){
			int result = 0;
			foreach(e;info){
				char[] temp = to!(char[])(e);
				result = dg(temp);
				if(result)
					break;
			}
			return result;
		}
	
		int opApply(scope int delegate(ref size_t, ref char[]) dg){
			int result = 0;
			foreach(i,e;info){
				char[] temp = to!(char[])(e);
				result = dg(i,temp);
				if(result)
					break;
			}
			return result;			
		}
		
		override string toString(){
			string result = "";
			foreach(e;info){
				result ~= e ~ "\n";
			}
			return result;
		}
		
		void append(string str){
			if(info is null){
				info = new string[1];
				info[0] = str;
			}
			else {
				info.length = info.length + 1;
				info[info.length-1] = str;
			}
		}
	}
	
	static Throwable.TraceInfo TraceHandler(void* ptr){
	  StackTrace trace = new StackTrace();
	  return trace.GetCallstack();
	}
	
public:
	static this(){
		Runtime.traceHandler(&TraceHandler);
		SetUnhandledExceptionFilter(&UnhandeledExceptionFilterHandler);
	}
	
	this(){
		if(isInit)
			return;
		HANDLE hProcess = GetCurrentProcess();
		DWORD pid = GetCurrentProcessId();
		
		Dbghelp.Init();
		string symPath = GenereateSearchPath();
		if(Dbghelp.SymInitialize(hProcess,cast(Dbghelp.PCSTR)toStringz(symPath),FALSE) != FALSE){
			isInit = true;
			
			DWORD symOptions = Dbghelp.SymGetOptions();
			symOptions |= Dbghelp.SYMOPT_LOAD_LINES;
			symOptions |= Dbghelp.SYMOPT_FAIL_CRITICAL_ERRORS;
			symOptions = Dbghelp.SymSetOptions(symOptions);
			
			LoadModules(hProcess,pid);
		}
	}
	
	Throwable.TraceInfo GetCallstack(){
		if(!isInit){
			writefln("Is not init!");
			return null;
		}
		
		HANDLE hThread = GetCurrentThread();
		HANDLE hProcess = GetCurrentProcess();
		
		//Capture the current context
		CONTEXT c;
		memset(&c, 0, CONTEXT.sizeof);
		c.ContextFlags = CONTEXT_FULL;
		RtlCaptureContext(&c);
		
		Dbghelp.STACKFRAME64 stackframe;
		memset(&stackframe,0,typeof(stackframe).sizeof);
		DWORD imageType;
		//x86
		imageType = Dbghelp.IMAGE_FILE_MACHINE_I386;
		stackframe.AddrPC.Offset = cast(Dbghelp.DWORD64)c.Eip;
		stackframe.AddrPC.Mode = Dbghelp.ADDRESS_MODE.AddrModeFlat;
		stackframe.AddrFrame.Offset = cast(Dbghelp.DWORD64)c.Ebp;
		stackframe.AddrFrame.Mode = Dbghelp.ADDRESS_MODE.AddrModeFlat;
		stackframe.AddrStack.Offset = cast(Dbghelp.DWORD64)c.Esp;
		stackframe.AddrStack.Mode = Dbghelp.ADDRESS_MODE.AddrModeFlat;
		
		size_t SymbolSize = Dbghelp.IMAGEHLP_SYMBOL64.sizeof + MAX_NAMELEN;
		Dbghelp.IMAGEHLP_SYMBOL64 *Symbol = cast(Dbghelp.IMAGEHLP_SYMBOL64*) malloc(SymbolSize);
		memset(Symbol,0,SymbolSize);
		Symbol.SizeOfStruct = SymbolSize;
		Symbol.MaxNameLength = MAX_NAMELEN;
		
		Dbghelp.IMAGEHLP_LINE64 Line;
		memset(&Line,0,typeof(Line).sizeof);
		Line.SizeOfStruct = typeof(Line).sizeof;
		
		Dbghelp.IMAGEHLP_MODULE64 Module;
		memset(&Module,0,typeof(Module).sizeof);
		Module.SizeOfStruct  = typeof(Module).sizeof;
		
		auto stack = new Callstack();
		
		//writefln("Callstack:");
		for(int frameNum=0;;frameNum++){
			if(Dbghelp.StackWalk64(imageType, hProcess, hThread, 
			                    &stackframe, &c, 
			                    null,
			                    cast(Dbghelp.FunctionTableAccessProc64)Dbghelp.SymFunctionTableAccess64,
			                    cast(Dbghelp.GetModuleBaseProc64)Dbghelp.SymGetModuleBase64,
			                    null) != TRUE )
			{
				//writefln("End of Callstack");
				break;
			}
			
			if(stackframe.AddrPC.Offset == stackframe.AddrReturn.Offset){
				//writefln("Endless callstack");
				stack.append("Endless callstack");
				break;
			}
			
			if(stackframe.AddrPC.Offset != 0){
				string lineStr = "";
				Dbghelp.DWORD64 offsetFromSymbol = cast(Dbghelp.DWORD64)0;
				if( Dbghelp.SymGetSymFromAddr64(hProcess,stackframe.AddrPC.Offset,&offsetFromSymbol,Symbol) == TRUE){
					char[] symName = new char[strlen(cast(const(char)*)Symbol.Name.ptr)+1];
					memcpy(symName.ptr,Symbol.Name.ptr,symName.length);
					string symString = "";
					if(symName[0] == 'D')
						symString = "_";
					symString ~= symName;
					
					string demangeledName = demangle(symString);
					lineStr ~= demangeledName;
					
					DWORD zeichen = 0;
					if(Dbghelp.SymGetLineFromAddr64(hProcess,stackframe.AddrPC.Offset,&zeichen,&Line) == TRUE){
						char[] fileName = new char[strlen(Line.FileName)];
						fileName[] = Line.FileName[0..fileName.length];
						lineStr = to!string(fileName ~ "::" ~ to!string(Line.LineNumber) ~ "(" ~ to!string(zeichen) ~ ") " ~ lineStr);
					}
				}
				else {
					lineStr = to!string(cast(ulong)stackframe.AddrPC.Offset);
				}
				lineStr = to!string(frameNum-2) ~ " " ~ lineStr;
				if(frameNum-2 < 10)
					lineStr = "0" ~ lineStr;
				if(frameNum >= 2)
					stack.append(lineStr);
			}
		}
		
		free(Symbol);
		return stack;
	}
 };

}
