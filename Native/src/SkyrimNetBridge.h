#pragma once
// SkyrimNetBridge — Reads SkyrimNet plugin configuration via PublicGetPluginConfigValue
// Uses GetModuleHandle + GetProcAddress so SkyrimNet.dll is NOT a build dependency.
// Gracefully returns defaults when SkyrimNet is absent or doesn't expose the config API.

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
            SKSE::log::info("SkyrimNetBridge: SkyrimNet.dll not found — plugin config unavailable");
            return;
        }

        m_getPluginConfigValue = reinterpret_cast<GetPluginConfigValue_t>(
            GetProcAddress(hDLL, "PublicGetPluginConfigValue"));
        m_getPluginConfig = reinterpret_cast<GetPluginConfig_t>(
            GetProcAddress(hDLL, "PublicGetPluginConfig"));

        m_available = (m_getPluginConfigValue != nullptr);

        if (m_available) {
            SKSE::log::info("SkyrimNetBridge: Plugin config API acquired successfully");
        } else {
            SKSE::log::info("SkyrimNetBridge: SkyrimNet.dll found but plugin config API not available "
                            "(requires SkyrimNet 0.15.4+ dev build)");
        }
    }

    // ── Accessors ─────────────────────────────────────────────────────

    bool IsAvailable() const { return m_available; }

    std::string GetString(const char* path, const char* defaultValue) const
    {
        if (!m_available || !m_getPluginConfigValue) {
            return defaultValue ? defaultValue : "";
        }
        try {
            return m_getPluginConfigValue("SeverActions", path, defaultValue);
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

    // ── Papyrus wrappers ──────────────────────────────────────────────

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

    // ── Registration ──────────────────────────────────────────────────

    static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
    {
        a_vm->RegisterFunction("PluginConfig_IsAvailable", scriptName, Papyrus_IsAvailable);
        a_vm->RegisterFunction("PluginConfig_GetString",   scriptName, Papyrus_GetString);
        a_vm->RegisterFunction("PluginConfig_GetBool",     scriptName, Papyrus_GetBool);
        a_vm->RegisterFunction("PluginConfig_GetInt",      scriptName, Papyrus_GetInt);
        a_vm->RegisterFunction("PluginConfig_GetFloat",    scriptName, Papyrus_GetFloat);

        SKSE::log::info("Registered SkyrimNet plugin config bridge functions");
    }

private:
    SkyrimNetBridge() = default;
    SkyrimNetBridge(const SkyrimNetBridge&) = delete;
    SkyrimNetBridge& operator=(const SkyrimNetBridge&) = delete;

    // Function pointer types matching SkyrimNet's PublicAPI exports
    using GetPluginConfigValue_t = std::string(*)(const char*, const char*, const char*);
    using GetPluginConfig_t      = std::string(*)(const char*);

    GetPluginConfigValue_t m_getPluginConfigValue = nullptr;
    GetPluginConfig_t      m_getPluginConfig      = nullptr;
    bool                   m_available             = false;
};
