defmodule PenguinMemories.Objects.Album do
  import Ecto.Query

  alias PenguinMemories.Repo
  alias PenguinMemories.Objects
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.File
  @behaviour Objects

  @impl Objects
  @spec get_icons() :: list(Objects.Icon.t)
  def get_icons() do
    query = from a in Album,
      join: p in Photo, on: p.id == a.cover_photo_id,
      join: f in File, on: p.id == f.photo_id,
      where: f.size_key == "thumb" and f.is_video == false,
      select: %{title: a.title, dir: f.dir, name: f.name, height: f.height, width: f.width}

    Enum.map(
      Repo.all(query),
      fn album ->
        IO.inspect(album);

        path = "https://photos.linuxpenguins.xyz/images/#{album.dir}/#{album.name}"
        IO.inspect(path);

        %Objects.Icon{url: path, title: album.title, height: album.height, width: album.width} end
    )
  end
end
