class_name LpcAssetPreloader
extends Node

## Deferred validator/cache for LPC sprite-sheet paths.
## Scans all paths derived from lpc_catalog.json on the first idle frame after start()
## and caches which ones exist on disk â€” prevents repeated FileAccess probes
## during character generation. Note: runs on the main thread (deferred, not threaded);
## for very large catalogs this may stall one frame. Use is_ready() to poll completion.

signal preload_complete(total: int, missing: int)

const _BODY_TYPES: Array[String] = [
	"male", "female", "teen", "child", "muscular", "pregnant",
	"skeleton", "zombie",
]

# item_id -> Array[String]  (all resolved .png paths for that item, any body)
var path_cache: Dictionary = {}
# item_id -> bool (true if at least one body's sheet exists)
var exists_cache: Dictionary = {}

var _catalog: LpcCatalog
var _total: int = 0
var _missing: int = 0
var _validated: bool = false


func start(catalog: LpcCatalog) -> void:
	_catalog = catalog
	_validated = false
	path_cache.clear()
	exists_cache.clear()
	# Defer scanning to avoid blocking _ready() / first frame.
	call_deferred("_scan_all")


func is_ready() -> bool:
	return _validated


func item_exists(item_id: String) -> bool:
	return exists_cache.get(item_id, true)   # default true = don't incorrectly hide items


# ---- internal ----

func _scan_all() -> void:
	if _catalog == null:
		preload_complete.emit(0, 0)
		return
	_total = 0
	_missing = 0
	for slot: String in _catalog.slot_names():
		for raw: Variant in _catalog.items_for_slot(slot):
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = raw
			var id: String = str(item.get("id", ""))
			if id.is_empty():
				continue
			if path_cache.has(id):
				continue   # already scanned this id from another slot
			var paths: Array[String] = []
			var any_found: bool = false
			for bt: String in _BODY_TYPES:
				if not LpcPath.item_supports_body(item, bt):
					continue
				var prefix: String = LpcPath.path_prefix_for_item(item, bt)
				if prefix.is_empty():
					continue
				var png: String = LpcPath.sheet_png(prefix, &"walk", "", "")
				paths.append(png)
				_total += 1
				if FileAccess.file_exists(png):
					any_found = true
				else:
					_missing += 1
			path_cache[id] = paths
			exists_cache[id] = any_found
	_validated = true
	preload_complete.emit(_total, _missing)
	if _missing > 0:
		push_warning(
			"LpcAssetPreloader: %d/%d sprite sheets missing on disk." % [_missing, _total]
		)
