#pragma once
// SkyrimNetBridge — Interface to SkyrimNet's PublicAPI via dynamic loading.
// Uses GetModuleHandle + GetProcAddress so SkyrimNet.dll is NOT a build dependency.
// Gracefully returns defaults when SkyrimNet is absent or on older versions.
//
// Plugin config API:   v3+ (PublicGetPluginConfigValue)
// Data query API:      v3+ (engagement, social graph, memories, events)
// Diary query API:     v4+ (PublicGetDiaryEntries)

#include <string>
#include <Windows.h>
#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>

class SkyrimNetBridge
{
public:
    static SkyrimNetBridge* GetSingleton()
    {
        static SkyrimNetBridge instance;
        return &instance;
    }

    // ── Lifecycle ──────────────────────────────────────────────────────

    /// Call once from kPostLoad (after all DLLs are loaded).
    void Initialize()
    {
        auto hDLL = GetModuleHandleA("SkyrimNet.dll");
        if (!hDLL) {
            SKSE::log::info("SkyrimNetBridge: SkyrimNet.dll not found — all APIs unavailable");
            return;
        }

        // Core: version check (v2+)
        m_getVersion = reinterpret_cast<GetVersion_t>(
            GetProcAddress(hDLL, "PublicGetVersion"));

        if (!m_getVersion) {
            SKSE::log::info("SkyrimNetBridge: SkyrimNet.dll found but PublicGetVersion not available");
            return;
        }

        m_apiVersion = m_getVersion();
        SKSE::log::info("SkyrimNetBridge: SkyrimNet PublicAPI version {}", m_apiVersion);

        // v3+ functions: config, data queries, UUID resolution
        if (m_apiVersion >= 3) {
            m_getPluginConfigValue = reinterpret_cast<GetPluginConfigValue_t>(
                GetProcAddress(hDLL, "PublicGetPluginConfigValue"));
            m_isMemorySystemReady = reinterpret_cast<IsMemorySystemReady_t>(
                GetProcAddress(hDLL, "PublicIsMemorySystemReady"));
            m_getActorEngagement = reinterpret_cast<GetActorEngagement_t>(
                GetProcAddress(hDLL, "PublicGetActorEngagement"));
            m_getRelatedActors = reinterpret_cast<GetRelatedActors_t>(
                GetProcAddress(hDLL, "PublicGetRelatedActors"));
            m_getMemoriesForActor = reinterpret_cast<GetMemoriesForActor_t>(
                GetProcAddress(hDLL, "PublicGetMemoriesForActor"));
            m_getRecentEvents = reinterpret_cast<GetRecentEvents_t>(
                GetProcAddress(hDLL, "PublicGetRecentEvents"));
            m_getPlayerContext = reinterpret_cast<GetPlayerContext_t>(
                GetProcAddress(hDLL, "PublicGetPlayerContext"));
            m_formIDToUUID = reinterpret_cast<FormIDToUUID_t>(
                GetProcAddress(hDLL, "PublicFormIDToUUID"));
            m_uuidToFormID = reinterpret_cast<UUIDToFormID_t>(
                GetProcAddress(hDLL, "PublicUUIDToFormID"));
            m_getActorNameByUUID = reinterpret_cast<GetActorNameByUUID_t>(
                GetProcAddress(hDLL, "PublicGetActorNameByUUID"));

            SKSE::log::info("SkyrimNetBridge: v3 data query functions resolved "
                "(engagement={}, relatedActors={}, memories={}, events={})",
                m_getActorEngagement != nullptr, m_getRelatedActors != nullptr,
                m_getMemoriesForActor != nullptr, m_getRecentEvents != nullptr);
        }

        // v4+ functions: diary queries
        if (m_apiVersion >= 4) {
            m_getDiaryEntries = reinterpret_cast<GetDiaryEntries_t>(
                GetProcAddress(hDLL, "PublicGetDiaryEntries"));

            SKSE::log::info("SkyrimNetBridge: v4 diary query functions resolved (diary={})",
                m_getDiaryEntries != nullptr);
        }

        m_available = (m_getPluginConfigValue != nullptr);

        if (m_available) {
            SKSE::log::info("SkyrimNetBridge: Plugin config API acquired successfully");
        }
    }

    // ── Status ────────────────────────────────────────────────────────

    bool IsAvailable() const { return m_available; }
    int  GetAPIVersion() const { return m_apiVersion; }

    /// Returns true if SkyrimNet's memory/database system is ready for queries.
    /// Safe to call even if PublicAPI is not loaded (returns false).
    bool IsPublicAPIReady() const
    {
        if (!m_isMemorySystemReady) return false;
        try { return m_isMemorySystemReady(); }
        catch (...) { return false; }
    }

    // ── Plugin Config Accessors ───────────────────────────────────────

    std::string GetString(const char* path, const char* defaultValue) const
    {
        if (!m_available) {
            return defaultValue ? defaultValue : "";
        }
        try {
            return m_getPluginConfigValue("SeverActions", path ? path : "", defaultValue);
        } catch (...) {
            SKSE::log::warn("SkyrimNetBridge: Exception reading config path '{}'", path ? path : "null");
            return defaultValue ? defaultValue : "";
        }
    }

    bool GetBool(const char* path, bool defaultValue) const
    {
        auto val = GetString(path, defaultValue ? "true" : "false");
        return val == "true" || val == "1" || val == "yes";
    }

    int GetInt(const char* path, int defaultValue) const
    {
        auto val = GetString(path, std::to_string(defaultValue).c_str());
        try { return std::stoi(val); }
        catch (...) { return defaultValue; }
    }

    float GetFloat(const char* path, float defaultValue) const
    {
        auto val = GetString(path, std::to_string(defaultValue).c_str());
        try { return std::stof(val); }
        catch (...) { return defaultValue; }
    }

    // ── Data Query Accessors (v3+) ────────────────────────────────────

    /// Get engagement stats for a specific actor.
    /// Returns JSON object for this actor, or "{}" if unavailable.
    std::string GetActorEngagement(uint32_t formId) const
    {
        if (!m_getActorEngagement || !IsPublicAPIReady()) return "{}";
        try {
            // Query engagement for all actors, then filter to the one we want.
            // Use 1-day short window (86400 game-seconds) and 7-day medium window.
            auto allJson = m_getActorEngagement(0, true, true, 86400.0, 604800.0);
            // Find our actor's entry in the array by formId
            return ExtractActorFromEngagementArray(allJson, formId);
        } catch (...) {
            SKSE::log::warn("SkyrimNetBridge: Exception in GetActorEngagement for {:08X}", formId);
            return "{}";
        }
    }

    /// Get actors related to a given actor via shared events.
    /// Returns JSON array, or "[]" if unavailable.
    std::string GetRelatedActors(uint32_t formId, int maxCount = 10) const
    {
        if (!m_getRelatedActors || !IsPublicAPIReady()) return "[]";
        try {
            return m_getRelatedActors(formId, maxCount, 86400.0, 604800.0);
        } catch (...) {
            SKSE::log::warn("SkyrimNetBridge: Exception in GetRelatedActors for {:08X}", formId);
            return "[]";
        }
    }

    /// Semantic memory search for an actor.
    /// Returns JSON array of memory objects, or "[]" if unavailable.
    std::string SearchMemories(uint32_t formId, const std::string& query, int maxCount = 5) const
    {
        if (!m_getMemoriesForActor || !IsPublicAPIReady()) return "[]";
        try {
            return m_getMemoriesForActor(formId, maxCount, query.c_str());
        } catch (...) {
            SKSE::log::warn("SkyrimNetBridge: Exception in SearchMemories for {:08X}", formId);
            return "[]";
        }
    }

    // ── Papyrus Wrappers: Plugin Config ───────────────────────────────

    static bool Papyrus_IsAvailable(RE::StaticFunctionTag*)
    {
        return GetSingleton()->IsAvailable();
    }

    static RE::BSFixedString Papyrus_GetString(RE::StaticFunctionTag*,
        RE::BSFixedString path, RE::BSFixedString defaultVal)
    {
        auto result = GetSingleton()->GetString(
            path.data() ? path.data() : "",
            defaultVal.data() ? defaultVal.data() : "");
        return result.c_str();
    }

    static bool Papyrus_GetBool(RE::StaticFunctionTag*,
        RE::BSFixedString path, bool defaultVal)
    {
        return GetSingleton()->GetBool(
            path.data() ? path.data() : "", defaultVal);
    }

    static int Papyrus_GetInt(RE::StaticFunctionTag*,
        RE::BSFixedString path, int defaultVal)
    {
        return GetSingleton()->GetInt(
            path.data() ? path.data() : "", defaultVal);
    }

    static float Papyrus_GetFloat(RE::StaticFunctionTag*,
        RE::BSFixedString path, float defaultVal)
    {
        return GetSingleton()->GetFloat(
            path.data() ? path.data() : "", defaultVal);
    }

    // ── Papyrus Wrappers: PublicAPI Data Queries ──────────────────────

    static bool Papyrus_IsPublicAPIReady(RE::StaticFunctionTag*)
    {
        return GetSingleton()->IsPublicAPIReady();
    }

    static RE::BSFixedString Papyrus_GetFollowerEngagement(RE::StaticFunctionTag*,
        RE::Actor* akActor)
    {
        if (!akActor) return "{}";
        auto result = GetSingleton()->GetActorEngagement(akActor->GetFormID());
        return result.c_str();
    }

    static RE::BSFixedString Papyrus_GetFollowerSocialGraph(RE::StaticFunctionTag*,
        RE::Actor* akActor)
    {
        if (!akActor) return "[]";
        auto result = GetSingleton()->GetRelatedActors(akActor->GetFormID(), 10);
        return result.c_str();
    }

    static RE::BSFixedString Papyrus_SearchActorMemories(RE::StaticFunctionTag*,
        RE::Actor* akActor, RE::BSFixedString query)
    {
        if (!akActor) return "[]";
        std::string queryStr = query.data() ? query.data() : "";
        auto result = GetSingleton()->SearchMemories(akActor->GetFormID(), queryStr, 5);
        return result.c_str();
    }

    // ── Registration ──────────────────────────────────────────────────

    static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        // Plugin config functions
        a_vm->RegisterFunction("PluginConfig_IsAvailable", scriptName, Papyrus_IsAvailable);
        a_vm->RegisterFunction("PluginConfig_GetString",   scriptName, Papyrus_GetString);
        a_vm->RegisterFunction("PluginConfig_GetBool",     scriptName, Papyrus_GetBool);
        a_vm->RegisterFunction("PluginConfig_GetInt",      scriptName, Papyrus_GetInt);
        a_vm->RegisterFunction("PluginConfig_GetFloat",    scriptName, Papyrus_GetFloat);

        // PublicAPI data query functions
        a_vm->RegisterFunction("IsPublicAPIReady",       scriptName, Papyrus_IsPublicAPIReady);
        a_vm->RegisterFunction("GetFollowerEngagement",  scriptName, Papyrus_GetFollowerEngagement);
        a_vm->RegisterFunction("GetFollowerSocialGraph", scriptName, Papyrus_GetFollowerSocialGraph);
        a_vm->RegisterFunction("SearchActorMemories",    scriptName, Papyrus_SearchActorMemories);

        SKSE::log::info("Registered SkyrimNet bridge functions (config + PublicAPI data queries)");
    }

private:
    SkyrimNetBridge() = default;
    SkyrimNetBridge(const SkyrimNetBridge&) = delete;
    SkyrimNetBridge& operator=(const SkyrimNetBridge&) = delete;

    // ── Helper: Extract a single actor from engagement array ──────────
    /// PublicGetActorEngagement returns an array of all actors. We extract the one
    /// matching our formId and return just that object.
    static std::string ExtractActorFromEngagementArray(const std::string& jsonArray, uint32_t formId)
    {
        // Quick search for the formId in the JSON string.
        // Format: "formId": 655544  (decimal)
        std::string needle = "\"formId\":" + std::to_string(formId);
        auto pos = jsonArray.find(needle);
        if (pos == std::string::npos) {
            // Try with space after colon
            needle = "\"formId\": " + std::to_string(formId);
            pos = jsonArray.find(needle);
        }
        if (pos == std::string::npos) return "{}";

        // Walk backwards to find the opening brace
        auto objStart = jsonArray.rfind('{', pos);
        if (objStart == std::string::npos) return "{}";

        // Walk forwards to find the matching closing brace
        int depth = 0;
        for (size_t i = objStart; i < jsonArray.size(); ++i) {
            if (jsonArray[i] == '{') depth++;
            else if (jsonArray[i] == '}') {
                depth--;
                if (depth == 0) {
                    return jsonArray.substr(objStart, i - objStart + 1);
                }
            }
        }
        return "{}";
    }

    // ── Function pointer typedefs ─────────────────────────────────────

    // Core (v2+)
    using GetVersion_t = int(*)();

    // Config (v3+)
    using GetPluginConfigValue_t = std::string(*)(const char*, const char*, const char*);

    // Status (v3+)
    using IsMemorySystemReady_t = bool(*)();

    // Data queries (v3+)
    using GetActorEngagement_t = std::string(*)(int, bool, bool, double, double);
    using GetRelatedActors_t = std::string(*)(uint32_t, int, double, double);
    using GetMemoriesForActor_t = std::string(*)(uint32_t, int, const char*);
    using GetRecentEvents_t = std::string(*)(uint32_t, int, const char*);
    using GetPlayerContext_t = std::string(*)(float);

    // UUID resolution (v3+)
    using FormIDToUUID_t = uint64_t(*)(uint32_t);
    using UUIDToFormID_t = uint32_t(*)(uint64_t);
    using GetActorNameByUUID_t = std::string(*)(uint64_t);

    // Diary (v4+)
    using GetDiaryEntries_t = std::string(*)(uint32_t, int, double, double);

    // ── Member variables ──────────────────────────────────────────────

    // Core
    GetVersion_t           m_getVersion           = nullptr;
    int                    m_apiVersion            = 0;

    // Config
    GetPluginConfigValue_t m_getPluginConfigValue  = nullptr;
    bool                   m_available             = false;

    // Status
    IsMemorySystemReady_t  m_isMemorySystemReady   = nullptr;

    // Data queries
    GetActorEngagement_t   m_getActorEngagement    = nullptr;
    GetRelatedActors_t     m_getRelatedActors      = nullptr;
    GetMemoriesForActor_t  m_getMemoriesForActor   = nullptr;
    GetRecentEvents_t      m_getRecentEvents       = nullptr;
    GetPlayerContext_t     m_getPlayerContext       = nullptr;

    // UUID resolution
    FormIDToUUID_t         m_formIDToUUID          = nullptr;
    UUIDToFormID_t         m_uuidToFormID          = nullptr;
    GetActorNameByUUID_t   m_getActorNameByUUID    = nullptr;

    // Diary
    GetDiaryEntries_t      m_getDiaryEntries       = nullptr;
};
