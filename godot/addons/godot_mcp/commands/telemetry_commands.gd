@tool
extends MCPBaseCommand
class_name MCP_Telemetry_Commands

# Fix #2: Contact Attribution — Telemetry singleton for deterministic tracking
var _instance = null

static func get_instance() -> MCP_Telemetry_Commands:
    if not _instance:
        _instance = MCP_Telemetry_Commands.new()
    return _instance

# Counters for deterministic tracking
var _hit_counters := {}
var _miss_counters := {}
var _consume_counters := {}
var _evade_counters := {}
var _collision_type_counters := {}

# Event log for audit trail
var _event_log := []
const MAX_EVENT_LOG_SIZE := 1000

# Timestamp for correlation
var _start_time := Time.get_ticks_msec()


# === Counter Registration ===

func register_hit(source: String, reason: String = "unknown") -> void:
    _increment_counter(_hit_counters, source, reason)
    _log_event({
        "type": "hit",
        "source": source,
        "reason": reason,
        "timestamp": _get_elapsed_time(),
        "frame": Engine.get_physics_frames()
    })


func register_miss(source: String, reason: String = "unknown") -> void:
    _increment_counter(_miss_counters, source, reason)
    _log_event({
        "type": "miss",
        "source": source,
        "reason": reason,
        "timestamp": _get_elapsed_time(),
        "frame": Engine.get_physics_frames()
    })


func register_consume(source: String, reason: String = "unknown") -> void:
    _increment_counter(_consume_counters, source, reason)
    _log_event({
        "type": "consume",
        "source": source,
        "reason": reason,
        "timestamp": _get_elapsed_time(),
        "frame": Engine.get_physics_frames()
    })


func register_evade(source: String, reason: String = "unknown") -> void:
    _increment_counter(_evade_counters, source, reason)
    _log_event({
        "type": "evade",
        "source": source,
        "reason": reason,
        "timestamp": _get_elapsed_time(),
        "frame": Engine.get_physics_frames()
    })


func register_collision_type(source: String, collision_type: String) -> void:
    _increment_counter(_collision_type_counters, source, collision_type)
    _log_event({
        "type": "collision_type",
        "source": source,
        "collision_type": collision_type,
        "timestamp": _get_elapsed_time(),
        "frame": Engine.get_physics_frames()
    })


# === Counter Queries ===

func get_counters(source: String = "") -> Dictionary:
    if source.is_empty():
        # Return all counters
        return {
            "hit": _hit_counters,
            "miss": _miss_counters,
            "consume": _consume_counters,
            "evade": _evade_counters,
            "collision_type": _collision_type_counters
        }
    else:
        # Return counters for specific source
        return {
            "hit": _hit_counters.get(source, 0),
            "miss": _miss_counters.get(source, 0),
            "consume": _consume_counters.get(source, 0),
            "evade": _evade_counters.get(source, 0),
            "collision_type": _collision_type_counters.get(source, {})
        }


func get_hit_count(source: String = "") -> Dictionary:
    if source.is_empty():
        return _hit_counters
    return { "hit_count": _hit_counters.get(source, 0) }


func get_miss_count(source: String = "") -> Dictionary:
    if source.is_empty():
        return _miss_counters
    return { "miss_count": _miss_counters.get(source, 0) }


func get_consume_count(source: String = "") -> Dictionary:
    if source.is_empty():
        return _consume_counters
    return { "consume_count": _consume_counters.get(source, 0) }


func get_stats_summary() -> Dictionary:
    var total_hits := 0
    var total_misses := 0
    var total_consumes := 0

    for source in _hit_counters:
        total_hits += _hit_counters[source]

    for source in _miss_counters:
        total_misses += _miss_counters[source]

    for source in _consume_counters:
        total_consumes += _consume_counters[source]

    return {
        "total_hits": total_hits,
        "total_misses": total_misses,
        "total_consumes": total_consumes,
        "hit_rate": float(total_hits) / max(1, total_hits + total_misses),
        "unique_sources": _get_unique_source_count(),
        "elapsed_time_ms": _get_elapsed_time(),
        "events_logged": _event_log.size()
    }


# === Event Logging ===

func get_events(limit: int = 100, event_type: String = "") -> Array:
    var events := _event_log

    # Filter by type if specified
    if not event_type.is_empty():
        events = events.filter(func(e): return e.get("type", "") == event_type)

    # Return last N events
    if limit > 0:
        return events.slice(-limit)

    return events


func get_events_by_source(source: String, limit: int = 100) -> Array:
    var events := _event_log.filter(func(e): return e.get("source", "") == source)

    if limit > 0:
        return events.slice(-limit)

    return events


func get_events_by_timerange(start_ms: int, end_ms: int) -> Array:
    return _event_log.filter(func(e):
        var timestamp = e.get("timestamp", 0)
        return timestamp >= start_ms and timestamp <= end_ms
    )


func get_recent_events(seconds: int = 10) -> Array:
    var cutoff_time := _get_elapsed_time() - (seconds * 1000)
    return _event_log.filter(func(e): return e.get("timestamp", 0) >= cutoff_time)


# === Cache Management ===

func clear_events(source: String = "") -> void:
    if source.is_empty():
        # Clear entire event log
        _event_log.clear()
    else:
        # Clear events for specific source
        _event_log = _event_log.filter(func(e): return e.get("source", "") != source)


func clear_counters(source: String = "") -> void:
    if source.is_empty():
        # Clear all counters
        _hit_counters.clear()
        _miss_counters.clear()
        _consume_counters.clear()
        _evade_counters.clear()
        _collision_type_counters.clear()
    else:
        # Clear counters for specific source
        _hit_counters.erase(source)
        _miss_counters.erase(source)
        _consume_counters.erase(source)
        _evade_counters.erase(source)
        _collision_type_counters.erase(source)


func clear_all() -> void:
    clear_events()
    clear_counters()
    _start_time = Time.get_ticks_msec()


# === MCP Commands ===

func get_commands() -> Dictionary:
    return {
        "get_counters": get_counters_command,
        "get_events": get_events_command,
        "clear_events": clear_events_command,
        "clear_counters": clear_counters_command,
        "get_stats_summary": get_stats_summary_command
    }


func get_counters_command(params: Dictionary) -> Dictionary:
    var source: String = params.get("source", "")

    return _success({
        "counters": get_counters(source)
    })


func get_events_command(params: Dictionary) -> Dictionary:
    var limit: int = params.get("limit", 100)
    var event_type: String = params.get("event_type", "")

    return _success({
        "events": get_events(limit, event_type),
        "count": get_events(limit, event_type).size()
    })


func clear_events_command(params: Dictionary) -> Dictionary:
    var source: String = params.get("source", "")
    clear_events(source)

    return _success({
        "cleared": true,
        "source": source if not source.is_empty() else "all"
    })


func clear_counters_command(params: Dictionary) -> Dictionary:
    var source: String = params.get("source", "")
    clear_counters(source)

    return _success({
        "cleared": true,
        "source": source if not source.is_empty() else "all"
    })


func get_stats_summary_command(params: Dictionary) -> Dictionary:
    return _success({
        "summary": get_stats_summary()
    })


# === Internal Helpers ===

func _increment_counter(counters: Dictionary, source: String, key: String) -> void:
    if not counters.has(source):
        counters[source] = {}

    if not counters[source].has(key):
        counters[source][key] = 0

    counters[source][key] += 1


func _log_event(event: Dictionary) -> void:
    _event_log.append(event)

    # Keep log size bounded
    if _event_log.size() > MAX_EVENT_LOG_SIZE:
        _event_log = _event_log.slice(-MAX_EVENT_LOG_SIZE / 2)


func _get_elapsed_time() -> int:
    return Time.get_ticks_msec() - _start_time


func _get_unique_source_count() -> int:
    var sources := {}

    for counter_dict in [_hit_counters, _miss_counters, _consume_counters]:
        for source in counter_dict:
            sources[source] = true

    return sources.size()
