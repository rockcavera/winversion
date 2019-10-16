## This package allows you to determine the running version of the Windows operating system.
##
## The two main features are:
## * get the name of the version of the operating system running;
## * and determine if the running version is equal to or greater than a particular version of Windows.
##
## Works only on Windows operating systems!
##
## Basic usage
## ===========
##
## .. code-block::
##
##   import winversion
##
##   # Get the name of the version of the operating system running.
##   let nameOS = getWindowsOS()
##   echo nameOS
##
##   # Determine if running version is equal to or higher than Windows Vista.
##   if isWindowsVistaOrGreater():
##     echo "It's Windows Vista or greater"
##   else:
##     echo "It's not Windows Vista or greater"
##
##   # Returns version information about the currently running operating system.
##   let info = getWindowsVersion()
##   echo info
##
##   # Returns version extended information about the currently running operating system.
##   let infoEx = getWindowsVersionEx()
##   echo infoEx

type
  WCHAR* = distinct uint16

  RTL_OSVERSIONINFOW* = object ## https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/content/wdm/ns-wdm-_osversioninfow
    dwOSVersionInfoSize*: uint32 ## The size in bytes of an RTL_OSVERSIONINFOW object.
    dwMajorVersion*: uint32 ## The major version number of the operating system.
    dwMinorVersion*: uint32 ## The minor version number of the operating system.
    dwBuildNumber*: uint32 ## The build number of the operating system.
    dwPlatformId*: uint32 ## The operating system platform.
    szCSDVersion*: array[128, WCHAR] ## The service-pack version string.
    
  RTL_OSVERSIONINFOEX* = object ## https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/content/wdm/ns-wdm-_osversioninfoexw
    dwOSVersionInfoSize*: uint32 ## The size, in bytes, of an RTL_OSVERSIONINFOEXW object.
    dwMajorVersion*: uint32 ## The major version number of the operating system.
    dwMinorVersion*: uint32 ## The minor version number of the operating system.
    dwBuildNumber*: uint32 ## The build number of the operating system.
    dwPlatformId*: uint32 ## The operating system platform.
    szCSDVersion*: array[128, WCHAR] ## The service-pack version string.
    wServicePackMajor*: uint16 ## The major version number of the latest service pack installed on the system.
    wServicePackMinor*: uint16 ## The minor version number of the latest service pack installed on the system.
    wSuiteMask*: uint16 ## The product suites available on the system.
    wProductType*: uint8 ## The product type.
    wReserved*: uint8 ## Reserved for future use.

const 
  VER_NT_WORKSTATION = 0x0000001'u8
  VER_SUITE_WH_SERVER = 0x00008000'u16
  SM_SERVERR2 = 89'i32

# https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/content/wdm/nf-wdm-rtlgetversion
proc rtlGetVersion(lpVersionInformation: ptr RTL_OSVERSIONINFOW | ptr RTL_OSVERSIONINFOEX): int32 {.stdcall, dynlib: "ntdll.dll", importc: "RtlGetVersion".}

# https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getsystemmetrics
proc getSystemMetrics(nIndex: int32): int32 {.stdcall, dynlib: "User32.dll", importc: "GetSystemMetrics".}

proc `$`*[I: static[Positive]](a: array[I, WCHAR]): string = $cast[WideCString](unsafeAddr a[0])

proc getWindowsVersion*(): RTL_OSVERSIONINFOW =
  ## Returns version information about the currently running operating system.
  ##
  ## Alternative to winlean.getVersion(), but it is not the same.
  result.dwOSVersionInfoSize = sizeof(RTL_OSVERSIONINFOW).uint32
  if rtlGetVersion(addr result) != 0:
    raise newException(OSError, "Call to RtlGetVersion failed")

proc getWindowsVersionEx*(): RTL_OSVERSIONINFOEX =
  ## Returns version extended information about the currently running operating system.
  ##
  ## Alternative to winlean.getVersionExW()
  result.dwOSVersionInfoSize = sizeof(RTL_OSVERSIONINFOEX).uint32
  if rtlGetVersion(addr result) != 0:
    raise newException(OSError, "Call to RtlGetVersion failed")

proc getWindowsOS*(): string =
  ## If it can be identified, returns the name of the running windows operating
  ## system. Otherwise returns the numeric version.
  ##
  ## Can differentiate server and workstation versions.
  ##
  ## If the version is a service pack, returns "NAME SPx", where x is the
  ## service pack version number.
  ##
  ## Return values currently supported:
  ## * Workstation: Windows 10, Windows 8.1, Windows 8, Windows 7, Windows Vista, Windows XP Professional x64 Edition, Windows XP, Windows 2000
  ## * Server: Windows Server 2016, Windows Server 2012 R2, Windows Server 2012, Windows Server 2008 R2, Windows Server 2008, Windows Home Server, Windows Server 2003 R2, Windows Server 2003
  let i = getWindowsVersionEx()

  case i.dwMajorVersion
  of 10:
    if VER_NT_WORKSTATION == i.wProductType:
      result = "Windows 10"
    else:
      result = "Windows Server 2016"
  of 6:
    if VER_NT_WORKSTATION == i.wProductType:
      case i.dwMinorVersion
      of 3: result = "Windows 8.1"
      of 2: result = "Windows 8"
      of 1: result = "Windows 7"
      of 0: result = "Windows Vista"
      else: discard
    else:
      case i.dwMinorVersion
      of 3: result = "Windows Server 2012 R2"
      of 2: result = "Windows Server 2012"
      of 1: result = "Windows Server 2008 R2"
      of 0: result = "Windows Server 2008"
      else: discard
  of 5:
    case i.dwMinorVersion
    of 2:
      if VER_NT_WORKSTATION == i.wProductType:
        result = "Windows XP Professional x64 Edition"
      elif VER_SUITE_WH_SERVER == (i.wSuiteMask and VER_SUITE_WH_SERVER):
        result = "Windows Home Server"
      elif getSystemMetrics(SM_SERVERR2) != 0:
        result = "Windows Server 2003 R2"
      else:
        result = "Windows Server 2003"
    of 1: result = "Windows XP"
    of 0: result = "Windows 2000"
    else: discard
  else: discard

  if "" == result:
    result = $i.dwMajorVersion & "." & $i.dwMinorVersion
  
  if i.wServicePackMajor > 0'u16:
    result &= " SP" & $i.wServicePackMajor

proc isWindowsOrGreater(majorVersion, minorVersion: uint32,
                        servicePackMajor: uint16): bool =
  let i = getWindowsVersionEx()

  if i.dwMajorVersion > majorVersion:
    result = true
  elif i.dwMajorVersion == majorVersion:
    if i.dwMinorVersion > minorVersion:
      result = true
    elif i.dwMinorVersion == minorVersion:
      if i.wServicePackMajor >= servicePackMajor:
        result = true

proc isWindows2000OrGreater*(): bool =
  ## Returns true if Operating System is Windows 2000 or greater
  isWindowsOrGreater(5'u32, 0'u32, 0'u16)

proc isWindowsXPOrGreater*(): bool =
  ## Returns true if Operating System is Windows XP or greater
  isWindowsOrGreater(5'u32, 1'u32, 0'u16)

proc isWindowsXPSP1OrGreater*(): bool =
  ## Returns true if Operating System is Windows XP SP1 or greater
  isWindowsOrGreater(5'u32, 1'u32, 1'u16)

proc isWindowsXPSP2OrGreater*(): bool =
  ## Returns true if Operating System is Windows XP SP2 or greater
  isWindowsOrGreater(5'u32, 1'u32, 2'u16)

proc isWindowsXPSP3OrGreater*(): bool =
  ## Returns true if Operating System is Windows XP SP3 or greater
  isWindowsOrGreater(5'u32, 1'u32, 3'u16)

proc isWindowsVistaOrGreater*(): bool =
  ## Returns true if Operating System is Windows Vista or greater
  isWindowsOrGreater(6'u32, 0'u32, 0'u16)

proc isWindowsVistaSP1OrGreater*(): bool =
  ## Returns true if Operating System is Windows Vista SP1 or greater
  isWindowsOrGreater(6'u32, 0'u32, 1'u16)

proc isWindowsVistaSP2OrGreater*(): bool =
  ## Returns true if Operating System is Windows Vista SP2 or greater
  isWindowsOrGreater(6'u32, 0'u32, 2'u16)

proc isWindows7OrGreater*(): bool =
  ## Returns true if Operating System is Windows 7 or greater
  isWindowsOrGreater(6'u32, 1'u32, 0'u16)

proc isWindows7SP1OrGreater*(): bool =
  ## Returns true if Operating System is Windows 7 SP1 or greater
  isWindowsOrGreater(6'u32, 1'u32, 1'u16)

proc isWindows8OrGreater*(): bool =
  ## Returns true if Operating System is Windows 8 or greater
  isWindowsOrGreater(6'u32, 2'u32, 0'u16)

proc isWindows8Point1OrGreater*(): bool =
  ## Returns true if Operating System is Windows 8.1 or greater
  isWindowsOrGreater(6'u32, 3'u32, 0'u16)

proc isWindows10OrGreater*(): bool =
  ## Returns true if Operating System is Windows 10 or greater
  isWindowsOrGreater(10'u32, 0'u32, 0'u16)

when isMainModule:
  # Get the name of the version of the operating system running.
  let nameOS = getWindowsOS()
  echo nameOS

  # Determine if running version is equal to or higher than Windows Vista.
  if isWindowsVistaOrGreater():
    echo "It's Windows Vista or greater"
  else:
    echo "It's not Windows Vista or greater"

  # Returns version information about the currently running operating system.
  let info = getWindowsVersion()
  echo info

  # Returns version extended information about the currently running operating system.
  let infoEx = getWindowsVersionEx()
  echo infoEx