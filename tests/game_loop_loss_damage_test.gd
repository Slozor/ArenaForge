extends GdUnitTestSuite


func test_creep_loss_deals_damage_and_advances_round() -> void:
	var runner := scene_runner("res://scenes/game/game_scene.tscn")
	await runner.simulate_frames(3)

	var scene: Node = runner.scene()
	var loop = scene as GameLoop

	GameManager.player_health = 100
	loop.current_phase = GameLoop.Phase.COMBAT
	loop.current_round_kind = "creep"
	loop.enemy_units.clear()

	loop.on_combat_ended(false)
	await runner.simulate_frames(2)

	assert_int(GameManager.player_health).is_less(100)
	assert_int(GameManager.current_round).is_equal(2)
	assert_int(int(loop.current_phase)).is_equal(int(GameLoop.Phase.PREPARATION))


func test_pvp_loss_deals_more_than_zero_damage() -> void:
	var runner := scene_runner("res://scenes/game/game_scene.tscn")
	await runner.simulate_frames(3)

	var scene: Node = runner.scene()
	var loop = scene as GameLoop

	GameManager.player_health = 100
	loop.current_phase = GameLoop.Phase.COMBAT
	loop.current_round_kind = "combat"
	loop.enemy_units.clear()

	loop.on_combat_ended(false)
	await runner.simulate_frames(2)

	assert_int(GameManager.player_health).is_less(100)
