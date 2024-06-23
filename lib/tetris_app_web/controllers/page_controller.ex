defmodule TetrisAppWeb.PageController do
  use TetrisAppWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
