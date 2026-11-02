: << 'CMDBLOCK'
@echo off
REM Polyglot hook dispatcher: valid as a Windows batch file and a bash script.
REM Windows: cmd.exe runs this block, finds bash (Git for Windows first) and
REM runs the named extensionless hook script. Unix: ":" makes the block a
REM no-op heredoc and the shell part below runs the script directly.
REM Pattern from obra/superpowers (MIT). Usage: run-hook.cmd <script> [args]

if "%~1"=="" (
    echo run-hook.cmd: missing script name >&2
    exit /b 1
)

setlocal
set "HOOK_DIR=%~dp0"
set "BASH_EXE="

if exist "C:\Program Files\Git\bin\bash.exe" set "BASH_EXE=C:\Program Files\Git\bin\bash.exe"
if not defined BASH_EXE if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "BASH_EXE=C:\Program Files (x86)\Git\bin\bash.exe"
if not defined BASH_EXE if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH_EXE=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"

REM No bash: exit quietly so the harness keeps working without the hook.
if not defined BASH_EXE exit /b 0

"%BASH_EXE%" "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%
CMDBLOCK

# Unix: run the named script with this bash. Splitting $0 by hand (rather than
# dirname) keeps working when the harness starts hooks with an empty PATH.
case "$0" in
  */* | *\\*) SCRIPT_DIR="$(cd "${0%[/\\]*}" && pwd)" ;;
  *) SCRIPT_DIR="$(pwd)" ;;
esac
SCRIPT_NAME="$1"
shift
exec "${BASH:-bash}" "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
