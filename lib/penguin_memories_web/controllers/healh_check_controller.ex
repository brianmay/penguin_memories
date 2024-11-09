defmodule PenguinMemoriesWeb.HealthCheckController do
  use PenguinMemoriesWeb, :controller

  alias PenguinMemories.Release

  def index(conn, _params) do
    case Release.health_check() do
      :ok ->
        text(conn, "HEALTHY")

      {:error, _reason} ->
        conn |> put_status(500) |> text("ERROR")
    end
  end
end
