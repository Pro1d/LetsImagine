extends Node

func _ready() -> void:
	var pid := WhalepassSingleton.get_or_create_player_id()
	var res := await WhalepassSingleton.enroll(pid)
	print("==> ", res)
	var res2 := await WhalepassSingleton.redirect_link()
	print("==> ", res2)
	var res3 := await WhalepassSingleton.player_inventory()
	print("==> ", res3)
	var res4 := await WhalepassSingleton.progress_challenge(Whalepass.challenge_kill_bad_teddy)
	print("==> ", res4)
	res3 = await WhalepassSingleton.player_inventory()
	print("==> ", res3)
	print("==> ", res3)
	var res5 := await WhalepassSingleton.progress_xp(150)
	print("==> ", res5)
	res3 = await WhalepassSingleton.player_inventory()
	print("==> ", res3)
	var res6 := await WhalepassSingleton.player_progress()
	print("==> ", res6)
	
