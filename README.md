# pcgbasic
This package allows you to determine the running version of the Windows operating system.

The two main features are:
* get the name of the version of the operating system running;
* and determine if the running version is equal to or greater than a particular version of Windows.

Works only on Windows operating systems!

# Install
Run the Nimble install command

``nimble install winversion``

# Basic usage

```nim
import winversion

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
```
