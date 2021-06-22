defmodule PenguinMemoriesWeb.RedirectController do
  use PenguinMemoriesWeb, :controller

  alias PenguinMemories.Database.Query
  alias PenguinMemories.Photos

  def photo(conn, params) do
    case Integer.parse(params["id"]) do
      {id, ""} ->
        Integer.parse(params["id"])
        type = Photos.Photo
        size = params["size"]
        icon = Query.query_icon_by_id(id, type, size)

        if icon != nil do
          redirect(conn, to: icon.url)
        else
          conn
          |> put_status(404)
          |> text("Photo not found")
        end

      _ ->
        conn
        |> put_status(400)
        |> text("Photo id is invalid")
    end
  end
end
