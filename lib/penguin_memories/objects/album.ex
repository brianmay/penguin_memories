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

  @spec query_objects(%{required(String.t()) => String.t()}, MapSet.t()|nil) :: Query.t()
  defp query_objects(filter_spec, nil) do
    query = from o in Album

    case filter_spec["parent_id"] do
      nil -> query
      id -> from o in query, where: o.parent_id == ^id
    end
  end

  @spec query_objects(%{required(String.t()) => String.t()}, MapSet.t()|nil) :: Query.t()
  defp query_objects(_, id_mapset) do
    from o in Album,
      where: o.id in ^id_mapset
  end

  @impl Objects
  @spec get_icons(%{required(String.t()) => String.t()}, String.t()|nil, String.t()|nil) :: {list(Objects.Icon.t), String.t()|nil, String.t()|nil, integer}
  def get_icons(filter_spec, before_key, after_key) do

    file_query = from f in File,
      where: f.size_key == "thumb" and f.is_video == false,
      distinct: f.photo_id,
      order_by: [asc: :id]

    query = from o in query_objects(filter_spec, nil)
    query = from o in query,
      left_join: p in Photo, on: p.id == o.cover_photo_id,
      left_join: f in subquery(file_query), on: f.photo_id == p.id,
      select: %{id: o.id, title: o.title, sort_name: o.sort_name, sort_order: o.sort_order, dir: f.dir, name: f.name, height: f.height, width: f.width},
      order_by: [asc: o.sort_name, asc: o.sort_order, asc: o.id]

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
