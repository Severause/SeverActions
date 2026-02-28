#pragma once

// SeverActionsNative - Book Utilities
// Extracts book text content from TESObjectBOOK forms using TESDescription::GetDescription
// Enables NPCs to read books aloud via SkyrimNet actions
// Author: Severause

#include <RE/Skyrim.h>
#include <SKSE/SKSE.h>
#include <string>
#include <regex>

#include "StringUtils.h"
#include "DBFBridge.h"

namespace SeverActionsNative
{
    class BookUtils
    {
    public:
        /**
         * Get the full text content of a book form.
         * Uses TESDescription::GetDescription to extract the DESC field.
         * Strips HTML-like tags ([pagebreak], <p>, <br>, etc.) and normalizes whitespace.
         *
         * @param form The form to extract text from (must be a TESObjectBOOK)
         * @return The book's full text content, or empty string if not a book or no text
         */
        static std::string GetBookText(RE::TESForm* form)
        {
            if (!form) {
                SKSE::log::warn("BookUtils::GetBookText - form is null");
                return "";
            }

            auto* book = form->As<RE::TESObjectBOOK>();
            if (!book) {
                SKSE::log::warn("BookUtils::GetBookText - form {:X} is not a book", form->GetFormID());
                return "";
            }

            // Check Dynamic Book Framework mapping first (soft dependency)
            // If DBF has a .txt file mapped for this book, return that instead of DESC
            if (DBFBridge::GetInstance().IsAvailable()) {
                const char* bookName = book->GetName();
                if (bookName && bookName[0] != '\0') {
                    std::string dbfText = DBFBridge::GetInstance().GetDBFBookText(bookName);
                    if (!dbfText.empty()) {
                        SKSE::log::debug("BookUtils::GetBookText - DBF override for '{}' ({} chars)",
                            bookName, dbfText.length());
                        return dbfText;
                    }
                }
            }

            // TESObjectBOOK inherits TESDescription at offset 0xA8
            // GetDescription extracts the DESC field (full book text)
            RE::BSString rawText;
            book->GetDescription(rawText, book);

            std::string text = rawText.c_str() ? rawText.c_str() : "";

            if (text.empty()) {
                SKSE::log::debug("BookUtils::GetBookText - book {:X} '{}' has no text content",
                    form->GetFormID(), form->GetName());
                return "";
            }

            // Strip HTML/formatting tags
            text = StripBookFormatting(text);

            SKSE::log::debug("BookUtils::GetBookText - extracted {} chars from '{}'",
                text.length(), form->GetName());

            return text;
        }

        /**
         * Find a book in an actor's inventory by name (case-insensitive partial match).
         * @param actor The actor whose inventory to search
         * @param bookName The name to search for
         * @return The book Form if found, nullptr otherwise
         */
        static RE::TESForm* FindBookInInventory(RE::Actor* actor, const std::string& bookName)
        {
            if (!actor || bookName.empty()) return nullptr;

            std::string lowerSearch = StringUtils::ToLower(bookName);
            auto inventory = actor->GetInventory();

            for (const auto& [form, data] : inventory) {
                if (!form) continue;
                if (data.first <= 0) continue;

                // Check if this is a book
                if (!form->As<RE::TESObjectBOOK>()) continue;

                const char* formName = form->GetName();
                if (!formName || formName[0] == '\0') continue;

                std::string lowerName = StringUtils::ToLower(formName);
                if (lowerName.find(lowerSearch) != std::string::npos) {
                    return form;
                }
            }

            return nullptr;
        }

        /**
         * Check if an actor has any books in their inventory.
         * @param actor The actor to check
         * @return true if the actor has at least one book
         */
        static bool HasBooks(RE::Actor* actor)
        {
            if (!actor) return false;

            auto inventory = actor->GetInventory();
            for (const auto& [form, data] : inventory) {
                if (!form) continue;
                if (data.first <= 0) continue;
                if (form->As<RE::TESObjectBOOK>()) return true;
            }

            return false;
        }

        /**
         * Get a comma-separated list of book names in an actor's inventory.
         * @param actor The actor whose inventory to search
         * @return Comma-separated book names, or empty string
         */
        static std::string ListBooks(RE::Actor* actor)
        {
            if (!actor) return "";

            std::string result;
            auto inventory = actor->GetInventory();

            for (const auto& [form, data] : inventory) {
                if (!form) continue;
                if (data.first <= 0) continue;
                if (!form->As<RE::TESObjectBOOK>()) continue;

                const char* formName = form->GetName();
                if (!formName || formName[0] == '\0') continue;

                if (!result.empty()) {
                    result += ", ";
                }
                result += formName;
            }

            return result;
        }

    private:
        /**
         * Strip HTML-like formatting tags from book text.
         * Skyrim books use tags like [pagebreak], <p>, <br>, <font>, etc.
         */
        static std::string StripBookFormatting(const std::string& raw)
        {
            std::string text = raw;

            // Replace [pagebreak] with newlines
            size_t pos = 0;
            while ((pos = text.find("[pagebreak]", pos)) != std::string::npos) {
                text.replace(pos, 11, "\n\n");
            }

            // Replace <br> and <br/> with newlines
            pos = 0;
            while ((pos = text.find("<br>", pos)) != std::string::npos) {
                text.replace(pos, 4, "\n");
            }
            pos = 0;
            while ((pos = text.find("<br/>", pos)) != std::string::npos) {
                text.replace(pos, 5, "\n");
            }
            pos = 0;
            while ((pos = text.find("<BR>", pos)) != std::string::npos) {
                text.replace(pos, 4, "\n");
            }

            // Replace </p> with newlines (paragraph ends)
            pos = 0;
            while ((pos = text.find("</p>", pos)) != std::string::npos) {
                text.replace(pos, 4, "\n");
            }
            pos = 0;
            while ((pos = text.find("</P>", pos)) != std::string::npos) {
                text.replace(pos, 4, "\n");
            }

            // Strip all remaining HTML-like tags: <anything>
            std::string cleaned;
            cleaned.reserve(text.size());
            bool inTag = false;
            for (char c : text) {
                if (c == '<') {
                    inTag = true;
                } else if (c == '>') {
                    inTag = false;
                } else if (!inTag) {
                    cleaned += c;
                }
            }

            // Normalize whitespace: collapse multiple spaces to single space
            std::string normalized;
            normalized.reserve(cleaned.size());
            bool lastWasSpace = false;
            bool lastWasNewline = false;
            for (char c : cleaned) {
                if (c == '\n' || c == '\r') {
                    if (!lastWasNewline) {
                        normalized += '\n';
                        lastWasNewline = true;
                    }
                    lastWasSpace = false;
                } else if (c == ' ' || c == '\t') {
                    if (!lastWasSpace && !lastWasNewline) {
                        normalized += ' ';
                        lastWasSpace = true;
                    }
                } else {
                    normalized += c;
                    lastWasSpace = false;
                    lastWasNewline = false;
                }
            }

            // Trim leading/trailing whitespace
            size_t start = normalized.find_first_not_of(" \n\r\t");
            if (start == std::string::npos) return "";
            size_t end = normalized.find_last_not_of(" \n\r\t");
            return normalized.substr(start, end - start + 1);
        }

        // ====================================================================
        // PAPYRUS NATIVE FUNCTION WRAPPERS
        // ====================================================================

    public:
        static RE::BSFixedString Papyrus_GetBookText(RE::StaticFunctionTag*, RE::TESForm* form)
        {
            std::string text = GetBookText(form);
            return RE::BSFixedString(text.c_str());
        }

        static RE::TESForm* Papyrus_FindBookInInventory(RE::StaticFunctionTag*, RE::Actor* actor, RE::BSFixedString bookName)
        {
            if (!actor || !bookName.data()) return nullptr;
            return FindBookInInventory(actor, bookName.data());
        }

        static bool Papyrus_HasBooks(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            return HasBooks(actor);
        }

        static RE::BSFixedString Papyrus_ListBooks(RE::StaticFunctionTag*, RE::Actor* actor)
        {
            std::string list = ListBooks(actor);
            return RE::BSFixedString(list.c_str());
        }

        static void RegisterFunctions(RE::BSScript::IVirtualMachine* a_vm, const char* scriptName)
        {
            a_vm->RegisterFunction("GetBookText", scriptName, Papyrus_GetBookText);
            a_vm->RegisterFunction("FindBookInInventory", scriptName, Papyrus_FindBookInInventory);
            a_vm->RegisterFunction("HasBooks", scriptName, Papyrus_HasBooks);
            a_vm->RegisterFunction("ListBooks", scriptName, Papyrus_ListBooks);

            SKSE::log::info("Registered book utility functions");
        }
    };
}
