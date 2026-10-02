Scriptname SeverActionsNativeExt Hidden
{Compile-time stub for SeverActions's extension native surface — the
 Daegon Kaekiri patch only touches Native_Outfit_IsActivelyManaged so
 the stub is intentionally minimal.

 Real implementation lives in SeverActionsNative.dll. At runtime the
 patch guards on SeverActions.esp being loaded (Game.GetFormFromFile on
 the SA follower faction) before calling this — if SA isn't installed
 the call path is never taken, so the stub being a no-op .pex is fine
 (and per SeverActions's CLAUDE.md the stub .pex is NEVER deployed).}

Bool Function Native_Outfit_IsActivelyManaged(Actor akActor) Global Native
{True iff SeverActions is actively managing this actor's outfit RIGHT NOW.
 See SeverActionsNativeExt.psc in the SeverActions repo for the full
 semantics. Returns false when SA isn't installed.}
