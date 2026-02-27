# SeverActionsNative

High-performance SKSE plugin providing native C++ implementations for slow Papyrus operations in SeverActions.

## Performance Improvements

| Operation | Papyrus | Native | Speedup |
|-----------|---------|--------|---------|
| `StringToLower("Iron Sword")` | ~2-5ms | ~0.001ms | **2000-5000x** |
| `HexToInt("0x12EB7")` | ~1-3ms | ~0.0001ms | **10000x** |
| Crafting DB fuzzy search (1000 items) | ~500ms+ | ~1ms | **500x** |
| `FindItemByName()` (100 items) | ~50-100ms | ~0.5ms | **100-200x** |
| Travel cell lookup | ~20-50ms | ~0.01ms | **2000-5000x** |
| Nearby item search | 10+ calls | 1 call | **10x fewer calls** |

## Building

### Requirements
- CMake 3.21+
- Visual Studio 2022 with C++ workload
- vcpkg

### Build Commands
```bash
# Configure (first time - downloads dependencies)
cmake -B build -S . --preset=vs2022-windows-vcpkg

# Build
cmake --build build --config Release

# Output: build/Release/SeverActionsNative.dll
```

## Installation

1. Copy `SeverActionsNative.dll` to `Data/SKSE/Plugins/`
2. Copy `Scripts/SeverActionsNative.pex` to `Data/Scripts/` (compile from .psc)

## Papyrus Usage

```papyrus
; String utilities
string lower = SeverActionsNative.StringToLower("IRON SWORD")
int formId = SeverActionsNative.HexToInt("0x12EB7")
string trimmed = SeverActionsNative.TrimString("  hello  ")
bool contains = SeverActionsNative.StringContains("Iron Sword", "sword")

; Crafting database
SeverActionsNative.LoadCraftingDatabase("Data/SKSE/Plugins/SeverActions/CraftingDB/")
Form item = SeverActionsNative.FindCraftableByName("iron sword")
Form fuzzy = SeverActionsNative.FuzzySearchCraftable("iron")

; Travel database
SeverActionsNative.LoadTravelDatabase("Data/SKSE/Plugins/SeverActions/TravelDB/TravelMarkersVanilla.json")
string cellId = SeverActionsNative.FindCellId("whiterun")
ObjectReference marker = SeverActionsNative.ResolvePlace("Bannered Mare")

; Inventory helpers
Form item = SeverActionsNative.FindItemByName(actor, "health potion")
int value = SeverActionsNative.GetFormGoldValue(item)
bool consumable = SeverActionsNative.IsConsumable(item)

; Nearby search (replaces 10+ PO3 calls)
ObjectReference item = SeverActionsNative.FindNearbyItemOfType(actor, "sword", 1000.0)
ObjectReference forge = SeverActionsNative.FindNearbyForge(actor, 2000.0)
```

## Function Reference

### String Utilities
- `StringToLower(text)` - Convert to lowercase
- `HexToInt(hexString)` - Parse hex to int ("0x12EB7" or "12EB7")
- `TrimString(text)` - Trim whitespace
- `EscapeJsonString(text)` - Escape for JSON
- `StringContains(haystack, needle)` - Case-insensitive contains
- `StringEquals(a, b)` - Case-insensitive equals

### Crafting Database
- `LoadCraftingDatabase(folderPath)` - Load JSON files from folder
- `FindCraftableByName(name)` - O(1) exact match
- `FuzzySearchCraftable(term)` - Partial match with prefix index
- `SearchCraftableCategory(category, term)` - Search within category
- `IsCraftingDatabaseLoaded()` - Check if loaded
- `GetCraftingDatabaseStats()` - Get stats string

### Travel Database
- `LoadTravelDatabase(filePath)` - Load JSON file
- `FindCellId(placeName)` - Find cell ID (handles aliases)
- `GetMarkerForCell(cellId)` - Get XMarker reference
- `ResolvePlace(placeName)` - Combined lookup
- `IsTravelDatabaseLoaded()` - Check if loaded
- `GetTravelMarkerCount()` - Get marker count

### Inventory Utilities
- `FindItemByName(actor, name)` - Find in inventory
- `FindItemInContainer(container, name)` - Find in container
- `ActorHasItemByName(actor, name)` - Check existence
- `GetFormGoldValue(form)` - Get gold value (any type)
- `GetInventoryItemCount(container)` - Count unique items
- `IsConsumable(form)` - Check if consumable
- `IsFood(form)` - Check if food
- `IsPoison(form)` - Check if poison

### Nearby Search
- `FindNearbyItemOfType(actor, type, radius)` - Single-pass item search
- `FindNearbyContainer(actor, type, radius)` - Find container
- `FindNearbyForge(actor, radius)` - Find smithing station
- `GetDirectionString(actor, target)` - Direction ("ahead", "right", etc.)

## Dependencies
- CommonLibSSE-NG 3.7.0+
- nlohmann/json
- spdlog

## License
MIT License - See LICENSE file

## Author
Severause
