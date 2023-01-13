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
  cwchar_t = distinct uint16 # cushort https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/9e7d8bfc-016c-48b7-95ae-666e103eead4
  NTSTATUS* = int32 # clong https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/c8b512d5-70b1-4028-95f1-ec92d35cb51e
  UCHAR* = uint8 # cuchar https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/050baef1-f978-4851-a3c7-ad701a90e54a
  ULONG* = uint32 # culong https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/32862b84-f6e6-40f9-85ca-c4faf985b822
  USHORT* = uint16 # cushort https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/c0618c5b-362b-4e06-9cb0-8720d240cf12
  WCHAR* = cwchar_t # https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/7df7c1d5-492c-4db4-a992-5cd9e887c5d7

  RTL_OSVERSIONINFOW* = object ## https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/content/wdm/ns-wdm-_osversioninfow
    dwOSVersionInfoSize*: ULONG ## The size in bytes of an RTL_OSVERSIONINFOW object.
    dwMajorVersion*: ULONG ## The major version number of the operating system.
    dwMinorVersion*: ULONG ## The minor version number of the operating system.
    dwBuildNumber*: ULONG ## The build number of the operating system.
    dwPlatformId*: ULONG ## The operating system platform.
    szCSDVersion*: array[128, WCHAR] ## The service-pack version string.

  RTL_OSVERSIONINFOEXW* = object ## https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/content/wdm/ns-wdm-_osversioninfoexw
    dwOSVersionInfoSize*: ULONG ## The size, in bytes, of an RTL_OSVERSIONINFOEXW object.
    dwMajorVersion*: ULONG ## The major version number of the operating system.
    dwMinorVersion*: ULONG ## The minor version number of the operating system.
    dwBuildNumber*: ULONG ## The build number of the operating system.
    dwPlatformId*: ULONG ## The operating system platform.
    szCSDVersion*: array[128, WCHAR] ## The service-pack version string.
    wServicePackMajor*: USHORT ## The major version number of the latest service pack installed on the system.
    wServicePackMinor*: USHORT ## The minor version number of the latest service pack installed on the system.
    wSuiteMask*: USHORT ## The product suites available on the system.
    wProductType*: UCHAR ## The product type.
    wReserved*: UCHAR ## Reserved for future use.
  RTL_OSVERSIONINFOEX* {.deprecated: "Use `RTL_OSVERSIONINFOEXW` instead".} = RTL_OSVERSIONINFOEXW

  PRTL_OSVERSIONINFOW* = ptr RTL_OSVERSIONINFOW | ptr RTL_OSVERSIONINFOEXW

const
  STATUS_SUCCESS = NTSTATUS(0x00000000) # https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/596a1078-e883-4972-9bbc-49e60bebca55
  VER_NT_WORKSTATION = UCHAR(0x0000001)
  VER_SUITE_WH_SERVER = USHORT(0x00008000)
  SM_SERVERR2 = cint(89)

# https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/content/wdm/nf-wdm-rtlgetversion
proc rtlGetVersion(lpVersionInformation: PRTL_OSVERSIONINFOW): NTSTATUS {.stdcall, dynlib: "ntdll.dll", importc: "RtlGetVersion".}

# https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getsystemmetrics
proc getSystemMetrics(nIndex: cint): cint {.stdcall, dynlib: "User32.dll", importc: "GetSystemMetrics".}

proc `$`*[I: static[Positive]](a: array[I, WCHAR]): string = $cast[WideCString](unsafeAddr a[0])

proc getWindowsVersion*(): RTL_OSVERSIONINFOW =
  ## Returns version information about the currently running operating system.
  ##
  ## Alternative to winlean.getVersion(), but it is not the same.
  result.dwOSVersionInfoSize = sizeof(RTL_OSVERSIONINFOW).ULONG
  if rtlGetVersion(addr result) != STATUS_SUCCESS:
    raise newException(OSError, "Call to `RtlGetVersion` failed")

proc getWindowsVersionEx*(): RTL_OSVERSIONINFOEXW =
  ## Returns version extended information about the currently running operating system.
  ##
  ## Alternative to winlean.getVersionExW()
  result.dwOSVersionInfoSize = sizeof(RTL_OSVERSIONINFOEXW).ULONG
  if rtlGetVersion(addr result) != STATUS_SUCCESS:
    raise newException(OSError, "Call to `RtlGetVersion` failed")

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
  ## * Workstation: Windows 11, Windows 10, Windows 8.1, Windows 8, Windows 7, Windows Vista, Windows XP Professional x64 Edition, Windows XP, Windows 2000
  ## * Server: Windows Server 2016, Windows Server 2012 R2, Windows Server 2012, Windows Server 2008 R2, Windows Server 2008, Windows Home Server, Windows Server 2003 R2, Windows Server 2003
  let i = getWindowsVersionEx()

  case i.dwMajorVersion
  of 10:
    if VER_NT_WORKSTATION == i.wProductType:
      if i.dwBuildNumber >= 22000: # https://learn.microsoft.com/en-us/answers/questions/547050/win32-api-to-detect-windows-11
        result = "Windows 11"
      else:
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

proc isWindows11OrGreater*(): bool =
  ## Returns true if Operating System is Windows 11 or greater
  let i = getWindowsVersionEx()

  if (i.dwMajorVersion >= 10) and (i.dwBuildNumber >= 22000):
    result = true

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
