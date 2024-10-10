class_name Whalepass
extends Node

signal enrolled
signal progress_updated
signal inventory_updated
signal link_received

class AnyResp:
	pass

class EnrollResp:
	var id: String
	var externalPlayerId: String # player id
	var gameId: String
	var userId: Variant # null
	var accountConnected: bool
	var createdAt: String
	var updatedAt: String

class RedirectLinkResp:
	var redirectionLink: String
	
class PlayerInventoryResp:
	var items: Array
	func get_item_names() -> Array[String]:
		var dict := {}
		for d: Dictionary in items:
			if d.has("name"):
				dict[d["name"]] = d["name"]
		var ret : Array[String]
		ret.append_array(dict.keys())
		return ret

class PlayerBaseProgressResp:
	var currentExp: int
	var lastCompletedLevel: int

const api_key_header := "X-Api-Key"
const api_key_value := "dc2abf737024ae762b8fd50a540e5efa"
const battlepass_id := "7d7c8434-3a28-4ef6-ba4e-0d66ccc1eae0"
const game_id := "8a39a5d5-ee51-4c31-bdd6-b50b6ec8f117"

#var player_id := ""
#var whalepass_pid := ""

var rest_call : RESTCall

func _generate_player_id() -> String:
	return "USER-" + Time.get_datetime_string_from_system().replace(":", "-") + "-" +  str(randi())
func get_or_create_player_id() -> String:
	var cfg := ConfigFile.new()
	cfg.load(Config.SAVE_PATH)
	var pid := Config.read_config("whalepass", "playerId", "") as String
	if pid == "":
		pid = _generate_player_id()
		Config.save_config("whalepass", "playerId", pid)
	return pid

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	rest_call = RESTCall.new()
	rest_call.custom_headers = [api_key_header+": "+api_key_value, "X-Battlepass-Id: "+battlepass_id]
	add_child(rest_call)

func is_enrolled() -> bool:
	return Config.read_config("whalepass", "enrolled", false)

func enroll() -> bool:
	if is_enrolled():
		return true
	var pid := get_or_create_player_id()
	var resp := EnrollResp.new()
	var success := rest_call.rest_call(
		"https://api.whalepass.gg/enrollments",
		resp, RESTCall.POST, ["Content-Type: application/json"],
		JSON.stringify({"playerId": pid, "gameId": game_id})
	)
	if not success:
		return false
	await rest_call.done
	#player_id = pid
	#whalepass_pid = resp.id
	Config.save_config("whalepass", "enrolled", true)
	enrolled.emit()
	return true

var _link := ""
func get_redirect_link() -> String:
	return _link
func redirect_link() -> String:
	var resp := RedirectLinkResp.new()
	var success := rest_call.rest_call(
		"https://api.whalepass.gg/players/%s/redirect?gameId=%s" % [get_or_create_player_id(), game_id],
		resp, RESTCall.GET, [],
		""
	)
	if not success:
		return ""
	await rest_call.done
	
	if rest_call._obj == null:
		return ""
	_link = resp.redirectionLink
	link_received.emit()
	return resp.redirectionLink

func progress_action(actionId: String) -> bool:
	var resp := AnyResp.new()
	var success := rest_call.rest_call(
		"https://api.whalepass.gg/players/%s/progress/action" % [get_or_create_player_id()],
		resp, RESTCall.POST, ["Content-Type: application/json"],
		JSON.stringify({"actionId": actionId, "gameId": game_id})
	)
	if not success:
		return false
	await rest_call.done
	
	if rest_call._obj == null:
		return false
	return true

func progress_xp(xp: int) -> bool:
	var resp := AnyResp.new()
	var success := rest_call.rest_call(
		"https://api.whalepass.gg/players/%s/progress/exp" % [get_or_create_player_id()],
		resp, RESTCall.POST, ["Content-Type: application/json"],
		JSON.stringify({"additionalExp": xp, "gameId": game_id})
	)
	if not success:
		return false
	await rest_call.done
	
	if rest_call._obj == null:
		return false
	return true

func progress_challenge(challenge_id: String) -> bool:
	var resp := AnyResp.new()
	var success := rest_call.rest_call(
		"https://api.whalepass.gg/players/%s/progress/challenge" % [get_or_create_player_id()],
		resp, RESTCall.POST, ["Content-Type: application/json"],
		JSON.stringify({"challengeId": challenge_id, "gameId": game_id})
	)
	if not success:
		return false
	await rest_call.done
	
	if rest_call._obj == null:
		return false
	return true

func player_inventory() -> bool:
	var resp := PlayerInventoryResp.new()
	var success := rest_call.rest_call(
		"https://api.whalepass.gg/players/%s/inventory?gameId=%s" % [get_or_create_player_id(), game_id],
		resp, RESTCall.GET, [],
		""
	)
	if not success:
		return false
	await rest_call.done
	
	if rest_call._obj == null:
		return false
	Config.update_inventory(resp.get_item_names())
	inventory_updated.emit()
	return true
	
func player_progress() -> int:
	var resp := PlayerBaseProgressResp.new()
	var success := rest_call.rest_call(
		"https://api.whalepass.gg/players/%s/progress/base?gameId=%s" % [get_or_create_player_id(), game_id],
		resp, RESTCall.GET, [],
		""
	)
	if not success:
		return -1
	await rest_call.done
	
	if rest_call._obj == null:
		return -1
	Config.xp = resp.currentExp
	progress_updated.emit()
	return resp.lastCompletedLevel

var updating := false
func trigger_update() -> void:
	print("WP updating, ", updating)
	if updating:
		return
	updating = true
	if not is_enrolled():
		print("WP enroll")
		await enroll()
	if is_enrolled():
		print("WP redirect_link")
		await redirect_link()
		print("WP player_progress")
		await player_progress()
		print("WP player_inventory")
		await player_inventory()
	print("WP done")
	updating = false
