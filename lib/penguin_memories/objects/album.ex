defmodule PenguinMemories.Objects.Album do
  import Ecto.Query

  alias PenguinMemories.Repo
  alias PenguinMemories.Objects
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumAscendant
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.File
  alias Ecto.Changeset
  alias Ecto.Multi

  @behaviour Objects

  @impl Objects
  @spec get_type_name() :: String.t()
  def get_type_name do
    "album"
  end

  @impl Objects
  @spec get_plural_title() :: String.t()
  def get_plural_title do
    "albums"
  end

  @spec query_objects(%{required(String.t()) => String.t()}, MapSet.t()|nil) :: Ecto.Query.t()
  defp query_objects(filter_spec, nil) do
    query = from o in Album

    case filter_spec["parent_id"] do
      nil -> query
      id -> from o in query, where: o.parent_id == ^id
    end
  end

  defp query_objects(_, id_mapset) do
    id_list = MapSet.to_list(id_mapset)
    from o in Album,
      where: o.id in ^id_list
  end

  def get_icon_from_result(result) do
    url = if result.dir do
      "https://photos.linuxpenguins.xyz/images/#{result.dir}/#{result.name}"
    end
    subtitle = if result.sort_name != "" and result.sort_order != "" do
      "#{result.sort_name}: #{result.sort_order}"
    end
    %Objects.Icon{
      id: result.id,
      action: nil,
      url: url,
      title: result.title,
      subtitle: subtitle,
      height: result.height,
      width: result.width
    }
  end

  @impl Objects
  @spec get_parent_ids(integer) :: list(integer())
  def get_parent_ids(id) do
    query = from o in Album,
      where: o.id == ^id,
      select: o.parent_id

    case Repo.one!(query) do
      nil -> []
      id -> [id]
    end
  end

  @impl Objects
  @spec get_child_ids(integer) :: list(integer())
  def get_child_ids(id) do
    query = from o in Album,
      where: o.parent_id == ^id,
      select: o.id

    Repo.all(query)
  end

  @impl Objects
  @spec get_index(integer) :: list(MapSet.t())
  def get_index(id) do
    query = from oa in AlbumAscendant,
      where: oa.descendant_id == ^id,
      select: {oa.ascendant_id, oa.position}

    Enum.reduce(Repo.all(query), MapSet.new(), fn result, mapset ->
      MapSet.put(mapset, result)
    end)
  end

  @impl Objects
  @spec create_index(integer, {integer, integer}) :: :ok
  def create_index(id, index) do
    {referenced_id, position} = index
    Repo.insert!(%AlbumAscendant{ascendant_id: referenced_id, descendant_id: id, position: position})
    :ok
  end

  @impl Objects
  @spec delete_index(integer, {integer, integer}) :: :ok
  def delete_index(id, index) do
    {referenced_id, _position} = index
    Repo.delete_all(
      from oa in AlbumAscendant,
      where: oa.ascendant_id == ^referenced_id and oa.descendant_id == ^id
    )
    :ok
  end

  @impl Objects
  @spec get_bulk_update_fields() :: list(Objects.Field.t())
  def get_bulk_update_fields do
    [
      %Objects.Field{
        id: :title,
        title: "Title",
        display: nil,
        type: :string,
      },
      %Objects.Field{
        id: :parent_id,
        title: "Parent ID",
        display: nil,
        type: :album,
      },
      %Objects.Field{
        id: :sort_name,
        title: "Sort Name",
        display: nil,
        type: :string,
      },
      %Objects.Field{
        id: :sort_order,
        title: "Sort Order",
        display: nil,
        type: :string,
      },
      %Objects.Field{
        id: :revised,
        title: "Revised time",
        display: nil,
        type: :time,
      },
      %Objects.Field{
        id: :revised_utc_offset,
        title: "Revised timezone",
        display: nil,
        type: :utc_offset,
      },
    ]
  end

  @impl Objects
  @spec get_parents(integer) :: list(Objects.Icon.t())
  def get_parents(id) do
    file_query = from f in File,
      where: f.size_key == "thumb" and f.is_video == false,
      distinct: f.photo_id,
      order_by: [asc: :id]

    query = from ob in AlbumAscendant,
      where: ob.descendant_id == ^id,
      join: o in Album, on: o.id == ob.ascendant_id,
      left_join: p in Photo, on: p.id == o.cover_photo_id,
      left_join: f in subquery(file_query), on: f.photo_id == p.id,
      select: %{id: o.id, title: o.title, sort_name: o.sort_name, sort_order: o.sort_order, dir: f.dir, name: f.name, height: f.height, width: f.width},
      order_by: [desc: ob.position]

    icons = Enum.map(Repo.all(query), fn result ->
      get_icon_from_result(result)
    end)

    icons
  end

  @impl Objects
  @spec get_details(integer) :: {map(), Objects.Icon.t(), list(Objects.Field.t())} | nil
  def get_details(id) do
    file_query = from f in File,
      where: f.size_key == "mid" and f.is_video == false,
      distinct: f.photo_id,
      order_by: [asc: :id]

    query = from o in Album,
      where: o.id == ^id,
      left_join: p in Photo, on: p.id == o.cover_photo_id,
      left_join: f in subquery(file_query), on: f.photo_id == p.id,
      select: %{o: o, id: o.id, title: o.title, sort_name: o.sort_name, sort_order: o.sort_order, cp_title: p.title, dir: f.dir, name: f.name, height: f.height, width: f.width}

    case Repo.one(query) do
      nil -> nil
      result ->
        icon = get_icon_from_result(result)
        fields = [
          %Objects.Field{
            id: :title,
            title: "Title",
            display: result.o.title,
            type: :string,
          },
          %Objects.Field{
            id: :parent_id,
            title: "Parent ID",
            display: result.o.parent_id,
            type: :album,
          },
          %Objects.Field{
            id: :description,
            title: "Description",
            display: result.o.description,
            type: :markdown,
          },
          %Objects.Field{
            id: :cover_photo_id,
            title: "Cover Photo",
            display: "#{result.cp_title} (#{result.o.cover_photo_id})",
            type: :photo,
          },
          %Objects.Field{
            id: :sort_name,
            title: "Sort Name",
            display: result.o.sort_name,
            type: :string,
          },
          %Objects.Field{
            id: :sort_order,
            title: "Sort Order",
            display: result.o.sort_order,
            type: :string,
          },
          %Objects.Field{
            id: :revised,
            title: "Revised time",
            display: result.o.revised,
            type: :time,
          },
          %Objects.Field{
            id: :revised_utc_offset,
            title: "Revised timezone",
            display: result.o.revised_utc_offset,
            type: :utc_offset,
          },
        ]
        {result.o, icon, fields}
    end
  end

  @impl Objects
  @spec get_page_icons(%{required(String.t()) => String.t()}, MapSet.t()|nil, String.t()|nil, String.t()|nil) :: {list(Objects.Icon.t), String.t()|nil, String.t()|nil, integer}
  def get_page_icons(filter_spec, ids, before_key, after_key) do

    file_query = from f in File,
      where: f.size_key == "thumb" and f.is_video == false,
      distinct: f.photo_id,
      order_by: [asc: :id]

    query = from o in query_objects(filter_spec, ids)
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

    icons = Enum.map(entries, fn result ->
      get_icon_from_result(result)
    end)

    {icons, metadata.before, metadata.after, metadata.total_count}
  end


  @impl Objects
  @spec get_icons(MapSet.t()|nil, integer()) :: list(Objects.Icon.t)
  def get_icons(ids, limit) do

    file_query = from f in File,
      where: f.size_key == "thumb" and f.is_video == false,
      distinct: f.photo_id,
      order_by: [asc: :id]

    query = from o in query_objects(%{}, ids)
    query = from o in query,
      left_join: p in Photo, on: p.id == o.cover_photo_id,
      left_join: f in subquery(file_query), on: f.photo_id == p.id,
      select: %{id: o.id, title: o.title, sort_name: o.sort_name, sort_order: o.sort_order, dir: f.dir, name: f.name, height: f.height, width: f.width},
      order_by: [asc: o.sort_name, asc: o.sort_order, asc: o.id],
      limit: ^limit

    entries = Repo.all(query)

    icons = Enum.map(entries, fn result ->
      get_icon_from_result(result)
    end)

    icons
  end

  @impl Objects
  @spec create_child_changeset(map(), map()) :: Ecto.Changeset.t()
  def create_child_changeset(album, attrs) do
    Album.changeset(%Album{}, attrs)
    |> Changeset.put_change(:parent_id, album.id)
  end

  @impl Objects
  @spec update_changeset(map(), map()) :: Ecto.Changeset.t()
  def update_changeset(album, attrs) do
    Album.changeset(album, attrs)
  end

  @impl Objects
  @spec update(Changeset.t()) :: {:error, Changeset.t(), String.t()} | {:ok, map()}
  def update(%Changeset{data: %Album{}} = changeset) do
    result = Multi.new()
    |> Multi.insert_or_update(:update, changeset)
    |> Multi.run(:index, fn _, obj ->
      case Changeset.fetch_change(changeset, :parent_id) do
        :error ->
          {:ok, nil}
        {:ok, _value} ->
          Objects.fix_index_tree(obj.update.id, __MODULE__)
          {:ok, nil}
      end
    end)
    |> Repo.transaction()

    case result do
      {:ok, data} ->
        {:ok, data.update}
      {:error, :update, changeset, _} ->
        {:error, changeset, "The update failed"}
      {:error, :index, error, _} ->
        {:error, changeset, "Error #{inspect error} while indexing"}
    end
  end
end
