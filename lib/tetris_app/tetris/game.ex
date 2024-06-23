# lib/tetris_app/tetris/game.ex

defmodule TetrisApp.Tetris.Game do
  defstruct [:board, :current_piece, :next_piece, :score, :level, :game_over]

  @board_width 10
  @board_height 20
  @shapes [:i, :j, :l, :o, :s, :t, :z]

  require Logger

  def new do
    %__MODULE__{
      board: new_board(),
      current_piece: new_piece(),
      next_piece: new_piece(),
      score: 0,
      level: 1,
      game_over: false
    }
  end

  def tick(game) do
    Logger.debug("Tick called. Game state: #{inspect(game, pretty: true)}")

    if game.game_over do
      Logger.debug("Game over, no more ticks")
      game
    else
      cond do
        can_move?(game, :down) ->
          Logger.debug("Moving piece down")
          move_piece(game, :down)

        true ->
          Logger.debug("Cannot move down, processing end of piece")

          new_game =
            game
            |> lock_piece()
            |> clear_lines()
            |> add_new_piece()
            |> check_game_over()

          Logger.debug("Game state after processing: #{inspect(new_game, pretty: true)}")
          new_game
      end
    end
  end

  def handle_input(game, key) do
    Logger.debug("Input received: #{key}")

    if game.game_over do
      game
    else
      case key do
        "ArrowLeft" -> move_piece(game, :left)
        "ArrowRight" -> move_piece(game, :right)
        "ArrowDown" -> move_piece(game, :down)
        "ArrowUp" -> rotate_piece(game)
        " " -> hard_drop(game)
        _ -> game
      end
    end
  end

  def occupied?(game, {x, y}) do
    Enum.member?(game.board, {x, y})
  end

  def current_piece_at?(game, {x, y}) do
    Enum.member?(piece_to_coordinates(game.current_piece), {x, y})
  end

  def piece_to_coordinates(piece) do
    shape_coords(piece.shape, piece.position, piece.rotation)
  end

  defp new_board, do: []

  defp new_piece do
    shape = Enum.random(@shapes)

    %{
      shape: shape,
      rotation: 0,
      position: initial_position(shape)
    }
  end

  defp initial_position(:i), do: {3, 0}
  defp initial_position(_), do: {4, 0}

  defp can_move?(game, direction) do
    new_position = move_position(game.current_piece.position, direction)
    !collision?(game, game.current_piece.shape, new_position, game.current_piece.rotation)
  end

  defp move_piece(game, direction) do
    if can_move?(game, direction) do
      new_position = move_position(game.current_piece.position, direction)
      %{game | current_piece: %{game.current_piece | position: new_position}}
    else
      game
    end
  end

  defp move_position({x, y}, direction) do
    case direction do
      :left -> {x - 1, y}
      :right -> {x + 1, y}
      :down -> {x, y + 1}
    end
  end

  defp collision?(game, shape, {x, y}, rotation) do
    shape_coords(shape, {x, y}, rotation)
    |> Enum.any?(fn {px, py} ->
      px < 0 || px >= @board_width || py >= @board_height || Enum.member?(game.board, {px, py})
    end)
  end

  defp lock_piece(game) do
    Logger.debug("Locking piece: #{inspect(game.current_piece)}")
    new_board = game.board ++ piece_to_coordinates(game.current_piece)

    new_board =
      Enum.filter(new_board, fn {x, y} ->
        x >= 0 && x < @board_width && y >= 0 && y < @board_height
      end)

    Logger.debug("Board after locking: #{inspect(new_board)}")
    %{game | board: new_board}
  end

  defp clear_lines(game) do
    {new_board, cleared_lines} = do_clear_lines(game.board, 0)
    new_score = game.score + score_for_lines(cleared_lines)
    new_level = calculate_level(new_score)

    %{game | board: new_board, score: new_score, level: new_level}
  end

  defp do_clear_lines(board, cleared_lines) do
    case Enum.group_by(board, fn {_, y} -> y end) do
      lines when map_size(lines) == @board_height ->
        {board, cleared_lines}

      lines ->
        {new_board, extra_cleared} =
          lines
          |> Enum.sort_by(fn {y, _} -> y end, :desc)
          |> Enum.reduce({[], 0}, fn
            {_y, line}, {acc, cleared} when length(line) == @board_width ->
              {acc, cleared + 1}

            {y, line}, {acc, cleared} ->
              {line ++ Enum.map(acc, fn {x, _} -> {x, y + cleared} end), cleared}
          end)

        do_clear_lines(new_board, cleared_lines + extra_cleared)
    end
  end

  defp score_for_lines(0), do: 0
  defp score_for_lines(1), do: 100
  defp score_for_lines(2), do: 300
  defp score_for_lines(3), do: 500
  defp score_for_lines(4), do: 800

  defp calculate_level(score), do: div(score, 1000) + 1

  defp rotate_piece(game) do
    new_rotation = rem(game.current_piece.rotation + 1, 4)

    if !collision?(game, game.current_piece.shape, game.current_piece.position, new_rotation) do
      %{game | current_piece: %{game.current_piece | rotation: new_rotation}}
    else
      game
    end
  end

  defp hard_drop(game) do
    drop_distance =
      0..@board_height
      |> Enum.take_while(fn distance ->
        !collision?(
          game,
          game.current_piece.shape,
          {elem(game.current_piece.position, 0), elem(game.current_piece.position, 1) + distance},
          game.current_piece.rotation
        )
      end)
      |> Enum.count()
      |> Kernel.-(1)

    new_position =
      {elem(game.current_piece.position, 0), elem(game.current_piece.position, 1) + drop_distance}

    game
    |> Map.put(:current_piece, %{game.current_piece | position: new_position})
    |> lock_piece()
    |> clear_lines()
    |> add_new_piece()
    |> check_game_over()
  end

  defp add_new_piece(game) do
    Logger.debug("Adding new piece. Next piece was: #{inspect(game.next_piece)}")
    new_piece = %{game.next_piece | position: initial_position(game.next_piece.shape)}
    new_game = %{game | current_piece: new_piece, next_piece: new_piece()}
    Logger.debug("New game state after adding piece: #{inspect(new_game, pretty: true)}")
    new_game
  end

  defp check_game_over(game) do
    is_game_over =
      collision?(
        game,
        game.current_piece.shape,
        game.current_piece.position,
        game.current_piece.rotation
      )

    Logger.debug("Checking game over. Result: #{is_game_over}")
    %{game | game_over: is_game_over}
  end

  defp shape_coords(:i, {x, y}, rotation) do
    case rotation do
      0 -> [{x, y}, {x + 1, y}, {x + 2, y}, {x + 3, y}]
      1 -> [{x + 1, y}, {x + 1, y + 1}, {x + 1, y + 2}, {x + 1, y + 3}]
      2 -> [{x, y + 1}, {x + 1, y + 1}, {x + 2, y + 1}, {x + 3, y + 1}]
      3 -> [{x + 2, y}, {x + 2, y + 1}, {x + 2, y + 2}, {x + 2, y + 3}]
    end
  end

  defp shape_coords(:j, {x, y}, rotation) do
    case rotation do
      0 -> [{x, y}, {x, y + 1}, {x + 1, y + 1}, {x + 2, y + 1}]
      1 -> [{x + 1, y}, {x + 2, y}, {x + 1, y + 1}, {x + 1, y + 2}]
      2 -> [{x, y}, {x + 1, y}, {x + 2, y}, {x + 2, y + 1}]
      3 -> [{x + 1, y}, {x + 1, y + 1}, {x + 1, y + 2}, {x, y + 2}]
    end
  end

  defp shape_coords(:l, {x, y}, rotation) do
    case rotation do
      0 -> [{x + 2, y}, {x, y + 1}, {x + 1, y + 1}, {x + 2, y + 1}]
      1 -> [{x + 1, y}, {x + 1, y + 1}, {x + 1, y + 2}, {x + 2, y + 2}]
      2 -> [{x, y}, {x + 1, y}, {x + 2, y}, {x, y + 1}]
      3 -> [{x, y}, {x + 1, y}, {x + 1, y + 1}, {x + 1, y + 2}]
    end
  end

  defp shape_coords(:o, {x, y}, _) do
    [{x, y}, {x + 1, y}, {x, y + 1}, {x + 1, y + 1}]
  end

  defp shape_coords(:s, {x, y}, rotation) do
    case rotation do
      0 -> [{x + 1, y}, {x + 2, y}, {x, y + 1}, {x + 1, y + 1}]
      1 -> [{x + 1, y}, {x + 1, y + 1}, {x + 2, y + 1}, {x + 2, y + 2}]
      2 -> [{x + 1, y + 1}, {x + 2, y + 1}, {x, y + 2}, {x + 1, y + 2}]
      3 -> [{x, y}, {x, y + 1}, {x + 1, y + 1}, {x + 1, y + 2}]
    end
  end

  defp shape_coords(:t, {x, y}, rotation) do
    case rotation do
      0 -> [{x + 1, y}, {x, y + 1}, {x + 1, y + 1}, {x + 2, y + 1}]
      1 -> [{x + 1, y}, {x + 1, y + 1}, {x + 2, y + 1}, {x + 1, y + 2}]
      2 -> [{x, y + 1}, {x + 1, y + 1}, {x + 2, y + 1}, {x + 1, y + 2}]
      3 -> [{x + 1, y}, {x, y + 1}, {x + 1, y + 1}, {x + 1, y + 2}]
    end
  end

  defp shape_coords(:z, {x, y}, rotation) do
    case rotation do
      0 -> [{x, y}, {x + 1, y}, {x + 1, y + 1}, {x + 2, y + 1}]
      1 -> [{x + 2, y}, {x + 1, y + 1}, {x + 2, y + 1}, {x + 1, y + 2}]
      2 -> [{x, y + 1}, {x + 1, y + 1}, {x + 1, y + 2}, {x + 2, y + 2}]
      3 -> [{x + 1, y}, {x, y + 1}, {x + 1, y + 1}, {x, y + 2}]
    end
  end
end
