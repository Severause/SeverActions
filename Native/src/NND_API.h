#pragma once

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

/*
* NPC Names Distributor API - Soft dependency
* Copied from: https://github.com/adya/NPCs-Names-Distributor
*
* For modders: Copy this file into your own project if you wish to use this API
*/
namespace NND_API
{
	constexpr auto NNDPluginName = "NPCsNamesDistributor";

	// Available NND interface versions
	enum class InterfaceVersion : uint8_t
	{
		kV1,

		/// <summary>
		/// Introduces a new NameContext kDialogueHistory. Attempting to access it in older versions would return name for kOther context instead.
		/// </summary>
		kV2
	};

	enum class NameContext : uint8_t
	{
		kCrosshair = 1,
		kCrosshairMinion,

		kSubtitles,
		kDialogue,

		kInventory,

		kBarter,

		kEnemyHUD,

		kOther,

		kDialogueHistory
	};

	// NND's modder interface
	class IVNND1
	{
	public:
		/// <summary>
		/// Retrieves a generated name for given actor appropriate in specified context.
		/// </summary>
		virtual std::string_view GetName(RE::ActorHandle actor, NameContext context) noexcept = 0;

		/// <summary>
		/// Retrieves a generated name for given actor appropriate in specified context.
		/// </summary>
		virtual std::string_view GetName(RE::Actor* actor, NameContext context) noexcept = 0;

		/// <summary>
		/// Reveals a real name of the given actor to the player.
		/// </summary>
		virtual void RevealName(RE::ActorHandle actor) noexcept = 0;

		/// <summary>
		/// Reveals a real name of the given actor to the player.
		/// </summary>
		virtual void RevealName(RE::Actor* actor) noexcept = 0;
	};

	using IVNND2 = IVNND1;

	typedef void* (*_RequestPluginAPI)(const InterfaceVersion interfaceVersion);

	/// <summary>
	/// Request the NND API interface.
	/// Recommended: Send your request during or after SKSEMessagingInterface::kMessage_PostLoad
	/// </summary>
	[[nodiscard]] inline void* RequestPluginAPI(const InterfaceVersion a_interfaceVersion = InterfaceVersion::kV2) {
		const auto pluginHandle = GetModuleHandle(TEXT("NPCsNamesDistributor.dll"));
		if (pluginHandle) {
			if (const _RequestPluginAPI requestAPIFunction = reinterpret_cast<_RequestPluginAPI>(GetProcAddress(pluginHandle, "RequestPluginAPI"))) {
				return requestAPIFunction(a_interfaceVersion);
			}
		}
		return nullptr;
	}
}
