defmodule PenguinMemoriesWeb.HealthCheckController do
  use PenguinMemoriesWeb, :controller

  alias PenguinMemories.Release
  require Logger

  def index(conn, _params) do
    case Release.health_check() do
      :ok ->
        text(conn, "HEALTHY")

      {:error, reason} ->
        Logger.error("health check error: #{reason}")
        conn |> put_status(500) |> text("ERROR")
    end
  end
end
