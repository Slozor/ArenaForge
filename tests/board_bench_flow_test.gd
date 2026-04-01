extends GdUnitTestSuite


func test_can_add_unit_to_bench_and_place_on_valid_player_row() -> void:
	var runner := scene_runner("res://scenes/game/game_scene.tscn")
	await runner.simulate_frames(3)

	var bench = runner.find_child("BenchUI")
	var board = runner.find_child("BoardUI")

	assert_object(bench).is_not_null()
	assert_object(board).is_not_null()

	var added: bool = bench.add_unit_from_shop("iron_guard")
	assert_bool(added).is_true()
	assert_int(bench.get_unit_count()).is_equal(1)

	var unit = bench.get_all_units()[0]
	var placed: bool = board.place_unit_from_external(unit, Vector2i(0, 3))
	await runner.simulate_frames(1)

	assert_bool(placed).is_true()
	assert_int(board.get_unit_count()).is_equal(1)
	assert_int(bench.get_unit_count()).is_equal(0)


func test_cannot_place_unit_on_enemy_half_during_preparation() -> void:
	var runner := scene_runner("res://scenes/game/game_scene.tscn")
	await runner.simulate_frames(3)

	var bench = runner.find_child("BenchUI")
	var board = runner.find_child("BoardUI")

	var added: bool = bench.add_unit_from_shop("iron_guard")
	assert_bool(added).is_true()

	var unit = bench.get_all_units()[0]
	var placed: bool = board.place_unit_from_external(unit, Vector2i(0, 1))
	await runner.simulate_frames(1)

	assert_bool(placed).is_false()
	assert_int(board.get_unit_count()).is_equal(0)
	assert_int(bench.get_unit_count()).is_equal(1)
