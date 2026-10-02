Scriptname SeverActions_PrismaUI extends Quest
{Legacy shim (plan 2.4): stays attached to quest 0x000D62 so existing saves keep binding it; no
 properties, no page data, no live handlers. Its old duties moved: page data to the DLL
 (MagelightDataGatherer), the Actions page to the verb table (SeverActions_Verb_<Name>), the menu
 keys to MagelightSettingsHandler, package buttons to FollowerManager, bounty buttons to Arrest,
 item transfers to Init, the outfit migration to Outfit.}

Event OnInit()
    RegisterForPrismaEvents()
EndEvent

Function RegisterForPrismaEvents()
    ; M-I-STUB 3.9.14-beta25 (P4-08): this registered the data-request fallback and the key-code
    ; hand-off, and passed ten quest references to the DataGatherer, which now resolves them itself.
    ; A no-op for this script's OnInit and an old save's frame (F7).
EndFunction

Event OnPrismaExecuteAction(string eventName, string strArg, float numArg, Form sender)
    ; M-I-STUB 3.9.14-beta25 (P4-01): the DLL routes every Actions-page verb from Native/data/verb_table.json
    ; to the owning module's dispatcher (M-V); nothing sends this event, and an old save's registration lands here.
EndEvent
