defmodule TetrisApp.Repo do
  use Ecto.Repo,
    otp_app: :tetris_app,
    adapter: Ecto.Adapters.SQLite3
end
