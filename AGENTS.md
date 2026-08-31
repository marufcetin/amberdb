# Workspace Environment & Toolchain Rules

## Binary & Interpreter Paths

- **Perl (MSYS2)**: `C:\msys64\usr\bin\perl.exe`
  - When running Perl scripts, tests, or one-liners, always invoke via:
    `C:\msys64\usr\bin\perl.exe -Ilib ...`
  - To run test files:
    `C:\msys64\usr\bin\perl.exe -Ilib -MTest::Harness -e "runtests(@ARGV)" t/*.t`
  - Because `C:\msys64` is outside the sandboxed workspace, run commands with `BypassSandbox: true`.

- **Python**:
  - Windows Python: `C:\Python314\python.exe`
  - MSYS2 Python: `C:\msys64\usr\bin\python3.exe`

- **MSYS2 Toolchain**: `C:\msys64\usr\bin\`
