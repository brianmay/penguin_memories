defmodule PenguinMemoriesWeb.FileNotFoundController do
  use PenguinMemoriesWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(404)
    |> text("File Not Found 404 times")
  end
end
