#pragma once

// SeverActionsNative - Dynamic Book Framework Bridge
// Soft dependency: reads DBF's INI config files to map book names to .txt files
// When GetBookText() is called for a DBF-mapped book, reads the .txt instead of DESC
// If DBF is not installed, everything degrades gracefully - no crashes, no errors
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <string>
#include <unordered_map>
#include <shared_mutex>
#include <fstream>
#include <filesystem>
#include <sstream>

#include "StringUtils.h"

namespace SeverActionsNative
{
    /**
     * Bridge to Dynamic Book Framework
     *
     * DBF maps book display names to .txt files on disk. When a book is opened
     * in-game, DBF's DLL swaps the rendered content with the .txt file. But our
     * native GetBookText() reads the DESC field directly, bypassing DBF.
     *
     * This bridge:
     * 1. Scans DBF's INI config files at kDataLoaded to build a name -> filename map
     * 2. When GetBookText() is called, checks this map first
     * 3. If found, reads the .txt file and returns that instead of the DESC field
     * 4. If not found, falls through to normal DESC extraction
     *
     * File reads are NOT cached - content is read fresh every time since
     * DBF's AppendToFile() can modify .txt files at runtime.
     */
    class DBFBridge
    {
    public:
        static DBFBridge& GetInstance()
        {
            static DBFBridge instance;
            return instance;
        }

        /**
         * Initialize the bridge - check for DBF and scan INI files
         * Called at kDataLoaded
         * @return true if DBF is installed and mappings were loaded
         */
        bool Initialize()
        {
            std::unique_lock<std::shared_mutex> lock(m_mutex);

            m_available = false;
            m_initialized = false;
            m_bookMap.clear();

            // Check if Dynamic Book Framework ESP is loaded
            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) {
                SKSE::log::info("DBFBridge: DataHandler not available");
                return false;
            }

            const RE::TESFile* dbfFile = dataHandler->LookupModByName(DBF_ESP_NAME);
            if (!dbfFile) {
                SKSE::log::info("DBFBridge: {} not found — integration disabled", DBF_ESP_NAME);
                return false;
            }

            SKSE::log::info("DBFBridge: Found {} — scanning config files...", DBF_ESP_NAME);

            // Verify the config folder exists
            m_dbfBasePath = std::filesystem::path(DBF_FOLDER);
            if (!std::filesystem::exists(m_dbfBasePath)) {
                SKSE::log::warn("DBFBridge: Config folder not found at '{}' — integration disabled", DBF_FOLDER);
                return false;
            }

            // Scan Configs/*.ini
            std::filesystem::path configsDir = m_dbfBasePath / DBF_CONFIGS_FOLDER;
            if (std::filesystem::exists(configsDir) && std::filesystem::is_directory(configsDir)) {
                for (const auto& entry : std::filesystem::directory_iterator(configsDir)) {
                    if (entry.is_regular_file()) {
                        std::string ext = entry.path().extension().string();
                        // Case-insensitive .ini check
                        std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
                        if (ext == ".ini") {
                            ParseINI(entry.path());
                        }
                    }
                }
            }

            // Also parse UserBooks.ini from the root DBF folder
            std::filesystem::path userBooksPath = m_dbfBasePath / DBF_USERBOOKS_INI;
            if (std::filesystem::exists(userBooksPath)) {
                ParseINI(userBooksPath);
            }

            m_available = true;
            m_initialized = true;

            SKSE::log::info("DBFBridge: Loaded {} book mapping(s)", m_bookMap.size());
            for (const auto& [name, file] : m_bookMap) {
                SKSE::log::debug("DBFBridge:   '{}' -> '{}'", name, file);
            }

            return true;
        }

        /**
         * Re-scan all INI files to pick up new mappings
         * Call after creating new books via AppendToFile
         */
        void ReloadMappings()
        {
            std::unique_lock<std::shared_mutex> lock(m_mutex);

            if (!m_initialized) {
                SKSE::log::debug("DBFBridge: ReloadMappings called but bridge never initialized — skipping");
                return;
            }

            m_bookMap.clear();

            // Re-scan Configs/*.ini
            std::filesystem::path configsDir = m_dbfBasePath / DBF_CONFIGS_FOLDER;
            if (std::filesystem::exists(configsDir) && std::filesystem::is_directory(configsDir)) {
                for (const auto& entry : std::filesystem::directory_iterator(configsDir)) {
                    if (entry.is_regular_file()) {
                        std::string ext = entry.path().extension().string();
                        std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
                        if (ext == ".ini") {
                            ParseINI(entry.path());
                        }
                    }
                }
            }

            // Re-scan UserBooks.ini
            std::filesystem::path userBooksPath = m_dbfBasePath / DBF_USERBOOKS_INI;
            if (std::filesystem::exists(userBooksPath)) {
                ParseINI(userBooksPath);
            }

            SKSE::log::info("DBFBridge: Reloaded — {} book mapping(s)", m_bookMap.size());
        }

        /**
         * Check if DBF is installed and mappings were loaded
         */
        bool IsAvailable() const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            return m_available;
        }

        /**
         * Look up a book by display name
         * @return The .txt filename, or empty string if not mapped
         */
        std::string FindMapping(const std::string& bookDisplayName) const
        {
            std::shared_lock<std::shared_mutex> lock(m_mutex);
            if (!m_available) return "";

            std::string lowerName = StringUtils::ToLower(bookDisplayName);
            auto it = m_bookMap.find(lowerName);
            if (it != m_bookMap.end()) {
                return it->second;
            }
            return "";
        }

        /**
         * Read the .txt file contents for a given filename
         * Reads fresh every time — NOT cached (AppendToFile modifies at runtime)
         * @return File contents, or empty string if not found/unreadable
         */
        std::string ReadBookFile(const std::string& filename) const
        {
            // No lock needed here — we're only reading the filesystem, not m_bookMap
            std::filesystem::path filePath = m_dbfBasePath / DBF_BOOKS_FOLDER / filename;

            if (!std::filesystem::exists(filePath)) {
                SKSE::log::warn("DBFBridge: Book file not found: '{}'", filePath.string());
                return "";
            }

            std::ifstream file(filePath, std::ios::in);
            if (!file.is_open()) {
                SKSE::log::warn("DBFBridge: Could not open book file: '{}'", filePath.string());
                return "";
            }

            // Read entire file into string
            std::ostringstream ss;
            ss << file.rdbuf();
            std::string content = ss.str();

            // Strip UTF-8 BOM if present
            if (content.size() >= 3 &&
                static_cast<unsigned char>(content[0]) == 0xEF &&
                static_cast<unsigned char>(content[1]) == 0xBB &&
                static_cast<unsigned char>(content[2]) == 0xBF) {
                content = content.substr(3);
            }

            // Trim leading/trailing whitespace
            size_t start = content.find_first_not_of(" \t\r\n");
            if (start == std::string::npos) return "";
            size_t end = content.find_last_not_of(" \t\r\n");
            content = content.substr(start, end - start + 1);

            SKSE::log::debug("DBFBridge: Read {} chars from '{}'", content.length(), filePath.string());
            return content;
        }

        /**
         * Combined: given a book display name, return .txt contents or empty string
         * This is the main entry point called from BookUtils::GetBookText()
         */
        std::string GetDBFBookText(const std::string& bookDisplayName) const
        {
            std::string filename = FindMapping(bookDisplayName);
            if (filename.empty()) return "";
            return ReadBookFile(filename);
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

        static bool Papyrus_IsDBFInstalled(RE::StaticFunctionTag*)
        {
            return GetInstance().IsAvailable();
        }

        static void Papyrus_ReloadDBFMappings(RE::StaticFunctionTag*)
        {
            GetInstance().ReloadMappings();
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("IsDBFInstalled", scriptName, Papyrus_IsDBFInstalled);
            a_vm->RegisterFunction("ReloadDBFMappings", scriptName, Papyrus_ReloadDBFMappings);

            SKSE::log::info("Registered Dynamic Book Framework bridge functions");
        }

    private:
        DBFBridge() = default;
        DBFBridge(const DBFBridge&) = delete;
        DBFBridge& operator=(const DBFBridge&) = delete;

        /**
         * Parse a single INI file and add [Books] entries to the map
         * Format: BookDisplayName = filename.txt
         */
        void ParseINI(const std::filesystem::path& iniPath)
        {
            std::ifstream file(iniPath, std::ios::in);
            if (!file.is_open()) {
                SKSE::log::warn("DBFBridge: Could not open INI: '{}'", iniPath.string());
                return;
            }

            SKSE::log::debug("DBFBridge: Parsing INI: '{}'", iniPath.string());

            bool inBooksSection = false;
            std::string line;
            int entriesAdded = 0;

            while (std::getline(file, line)) {
                // Strip carriage return (handle CRLF)
                if (!line.empty() && line.back() == '\r') {
                    line.pop_back();
                }

                // Strip UTF-8 BOM from first line
                if (entriesAdded == 0 && !inBooksSection && line.size() >= 3 &&
                    static_cast<unsigned char>(line[0]) == 0xEF &&
                    static_cast<unsigned char>(line[1]) == 0xBB &&
                    static_cast<unsigned char>(line[2]) == 0xBF) {
                    line = line.substr(3);
                }

                // Trim whitespace
                size_t start = line.find_first_not_of(" \t");
                if (start == std::string::npos) continue;
                line = line.substr(start);
                size_t end = line.find_last_not_of(" \t");
                if (end != std::string::npos) {
                    line = line.substr(0, end + 1);
                }

                // Skip empty lines and comments
                if (line.empty() || line[0] == ';' || line[0] == '#') continue;

                // Check for section headers
                if (line[0] == '[') {
                    // Check if this is the [Books] section (case-insensitive)
                    std::string lowerLine = StringUtils::ToLower(line);
                    inBooksSection = (lowerLine == "[books]");
                    continue;
                }

                // Only parse key=value pairs inside [Books] section
                if (!inBooksSection) continue;

                // Split on first '='
                size_t eqPos = line.find('=');
                if (eqPos == std::string::npos) continue;

                std::string key = line.substr(0, eqPos);
                std::string value = line.substr(eqPos + 1);

                // Trim whitespace from key and value
                auto trim = [](std::string& s) {
                    size_t st = s.find_first_not_of(" \t");
                    if (st == std::string::npos) { s.clear(); return; }
                    size_t en = s.find_last_not_of(" \t");
                    s = s.substr(st, en - st + 1);
                };
                trim(key);
                trim(value);

                if (key.empty() || value.empty()) continue;

                // Store with lowercase key for case-insensitive lookup
                std::string lowerKey = StringUtils::ToLower(key);
                m_bookMap[lowerKey] = value;
                entriesAdded++;
            }

            SKSE::log::debug("DBFBridge: Parsed {} entries from '{}'", entriesAdded, iniPath.filename().string());
        }

        // Data
        mutable std::shared_mutex m_mutex;
        bool m_available = false;
        bool m_initialized = false;

        // Book display name (lowercase) -> filename in Books folder
        std::unordered_map<std::string, std::string> m_bookMap;

        // Base path to DBF folder
        std::filesystem::path m_dbfBasePath;

        // Constants
        static constexpr const char* DBF_ESP_NAME = "Dynamic Book Framework.esp";
        static constexpr const char* DBF_FOLDER = "Data/SKSE/Plugins/DynamicBookFramework";
        static constexpr const char* DBF_CONFIGS_FOLDER = "Configs";
        static constexpr const char* DBF_BOOKS_FOLDER = "Books";
        static constexpr const char* DBF_USERBOOKS_INI = "UserBooks.ini";
    };
}
