Scriptname DBF_ScriptUtil Hidden
{
    COMPILE-TIME STUB for Dynamic Book Framework integration.
    This stub provides the function signatures needed to compile SeverActions
    scripts that call DBF functions. At runtime, the REAL DBF script is used.

    DO NOT deploy the compiled .pex from this stub - it is only for compilation.
    The actual DBF_ScriptUtil.pex comes from Dynamic Book Framework itself.

    To compile, include this directory in the import path:
    -i="...BuildStubs;...Source/Scripts;..."
}

; Append text to a book's .txt file in DBF's Books folder
; Returns true if successful
Bool Function AppendToFile(String fileName, String textToAppend) Global Native

; Reload the INI mappings (picks up new book entries)
Function ReloadDynamicBookINI() Global Native
