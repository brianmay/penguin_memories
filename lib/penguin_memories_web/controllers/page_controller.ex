defmodule PenguinMemoriesWeb.PageController do
  use PenguinMemoriesWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
