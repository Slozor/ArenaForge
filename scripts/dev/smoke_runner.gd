extends Node

const GAME_SCENE := "res://scenes/game/game_scene.tscn"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load(GAME_SCENE)
	if packed == null:
		push_error("SmokeRunner: failed to load game scene")
		get_tree().quit(1)
		return

	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	var loop = scene.get_node_or_null("GameLoop")
	if loop == null:
		push_error("SmokeRunner: missing GameLoop")
		get_tree().quit(1)
		return

	var guard: int = 0
	while GameManager.current_round <= loop.get_total_rounds() and guard < 64:
		guard += 1
		loop._sync_round_context()
		match str(loop.current_round_kind):
			"loot", "draft", "armory":
				loop._resolve_special_round()
				await get_tree().process_frame
				await _resolve_pending_choice(loop)
			_:
				await _seed_board(scene)
				loop.on_combat_ended(true)
				await get_tree().process_frame
		if GameManager.current_state == GameManager.GameState.GAME_OVER:
			break

	if guard >= 64:
		push_error("SmokeRunner: loop guard hit")
		get_tree().quit(1)
		return

	get_tree().quit(0)


func _resolve_pending_choice(loop) -> void:
	if loop._pending_reward_choices.size() > 0:
		var choice_id: String = str(loop._pending_reward_choices.keys()[0])
		var payload: Dictionary = loop._pending_reward_choices.get(choice_id, {})
		var choice_kind: String = "draft_reward" if payload.has("unit_id") else "loot_reward"
		loop._on_selection_chosen(choice_kind, choice_id)
		await get_tree().process_frame
	if GameManager.has_pending_augment_choice() and not GameManager.pending_augment_choices.is_empty():
		GameManager.choose_augment(str(GameManager.pending_augment_choices[0]))
		await get_tree().process_frame


func _seed_board(scene: Node) -> void:
	var bench = scene.get_node_or_null("BenchUI")
	var board = scene.get_node_or_null("BoardUI")
	if bench == null or board == null:
		return
	var wanted: Array[String] = ["iron_guard", "watchman", "elven_archer"]
	for unit_id in wanted:
		if int(bench.call("get_unit_count")) < 3:
			bench.call("add_unit_from_shop", unit_id)
	await get_tree().process_frame
	var bench_units: Array = bench.call("get_all_units")
	for unit in bench_units:
		if unit == null:
			continue
		var placed_units: Array = board.call("get_all_placed_units")
		if placed_units.size() >= GameManager.get_team_size_cap():
			break
		var target: Vector2i = _find_open_player_cell(placed_units)
		if target == Vector2i(-1, -1):
			break
		board.call("place_unit_from_external", unit, target)
		await get_tree().process_frame


func _find_open_player_cell(placed_units: Array) -> Vector2i:
	var occupied: Dictionary = {}
	for unit in placed_units:
		if unit != null:
			occupied[unit.board_position] = true
	for y in [3, 2, 1, 0]:
		for x in range(7):
			var pos := Vector2i(x, y)
			if not occupied.has(pos):
				return pos
	return Vector2i(-1, -1)
