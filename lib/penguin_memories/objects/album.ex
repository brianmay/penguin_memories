defmodule PenguinMemories.Objects.Album do
  import Ecto.Query

  alias PenguinMemories.Repo
  alias PenguinMemories.Objects
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.File
  @behaviour Objects

  @impl Objects
  @spec get_plural_title() :: String.t()
  def get_plural_title do
    "albums"
  end

  @impl Objects
  @spec get_icons(String.t()|nil, String.t()|nil) :: {list(Objects.Icon.t), String.t()|nil, String.t()|nil, integer}
  def get_icons(before_key, after_key) do

    file_query = from f in File,
      where: f.size_key == "thumb" and f.is_video == false,
      distinct: f.photo_id,
      order_by: [asc: :id]

    query = from a in Album,
      left_join: p in Photo, on: p.id == a.cover_photo_id,
      left_join: f in subquery(file_query), on: f.photo_id == p.id,
      select: %{id: a.id, title: a.title, sort_name: a.sort_name, sort_order: a.sort_order, dir: f.dir, name: f.name, height: f.height, width: f.width},
      order_by: [asc: a.sort_name, asc: a.sort_order, asc: a.id]

    %{entries: entries, metadata: metadata} = Repo.paginate(
      query, before: before_key, after: after_key,
      cursor_fields: [:sort_name, :sort_order, :id],
      limit: 10
    )

    icons = Enum.map( entries, fn album ->
      url = if album.dir do
          "https://photos.linuxpenguins.xyz/images/#{album.dir}/#{album.name}"
        end
      %Objects.Icon{url: url, title: album.title, height: album.height, width: album.width} end
    )

    {icons, metadata.before, metadata.after, metadata.total_count}
  end
end
