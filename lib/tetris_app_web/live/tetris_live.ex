# lib/tetris_app_web/live/tetris_live.ex

defmodule TetrisAppWeb.TetrisLive do
  use TetrisAppWeb, :live_view
  alias TetrisApp.Tetris.Game
  require Logger

  @tick_rate 500

  def mount(_params, _session, socket) do
    if connected?(socket) do
      schedule_tick()
    end

    {:ok, new_game(socket)}
  end

  def handle_event("keydown", %{"key" => key}, socket) do
    Logger.debug("Keydown event received: #{key}")
    game = Game.handle_input(socket.assigns.game, key)
    {:noreply, assign(socket, game: game)}
  end

  def handle_event("new_game", _, socket) do
    {:noreply, new_game(socket)}
  end

  def handle_info(:tick, socket) do
    new_game =
      try do
        Game.tick(socket.assigns.game)
      rescue
        e ->
          Logger.error("Error during game tick: #{inspect(e)}")
          Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
          socket.assigns.game
      end

    Logger.debug("Game after tick: #{inspect(new_game, pretty: true)}")

    unless new_game.game_over do
      schedule_tick()
    end

    {:noreply, assign(socket, game: new_game)}
  end

  defp new_game(socket) do
    assign(socket, game: Game.new())
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_rate)
  end

  def render(assigns) do
    ~L"""
    <div phx-window-keydown="keydown" class="game-container">
      <h1>Tetris</h1>
      <div class="game-board">
        <%= for y <- 0..19 do %>
          <div class="row">
            <%= for x <- 0..9 do %>
              <div class="cell <%= cell_class(assigns.game, {x, y}) %>"></div>
            <% end %>
          </div>
        <% end %>
      </div>
      <div class="game-info">
        <div class="score">Score: <%= @game.score %></div>
        <div class="level">Level: <%= @game.level %></div>
        <div class="next-piece">
          <h3>Next Piece:</h3>
          <div class="next-piece-preview">
            <%= for {_x, _y} <- Game.piece_to_coordinates(@game.next_piece) do %>
              <div class="preview-cell <%= @game.next_piece.shape %>"></div>
            <% end %>
          </div>
        </div>
      </div>
      <%= if @game.game_over do %>
        <div class="game-over">
          <h2>Game Over!</h2>
          <p>Final Score: <%= @game.score %></p>
          <button phx-click="new_game">New Game</button>
        </div>
      <% end %>
    </div>
    """
  end

  defp cell_class(game, {x, y}) do
    cond do
      Game.current_piece_at?(game, {x, y}) -> game.current_piece.shape
      Game.occupied?(game, {x, y}) -> "occupied"
      true -> ""
    end
  end
end
