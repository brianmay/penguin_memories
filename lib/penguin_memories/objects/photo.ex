defmodule PenguinMemories.Objects.Photo do
  @moduledoc """
  Photo specific functions.
  """
  import Ecto.Query
  alias Ecto.Changeset
  alias Ecto.Multi

  alias PenguinMemories.Repo
  alias PenguinMemories.Objects
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.File

  @behaviour Objects

  @impl Objects
  @spec get_type_name() :: String.t()
  def get_type_name do
    "photo"
  end

  @impl Objects
  @spec get_plural_title() :: String.t()
  def get_plural_title do
    "photos"
  end

  @spec query_objects(%{required(String.t()) => String.t()}, MapSet.t()|nil) :: Ecto.Query.t()
  defp query_objects(_, id_mapset) when not is_nil(id_mapset) do
    id_list = MapSet.to_list(id_mapset)
    from o in Photo,
      as: :object,
      where: o.id in ^id_list
  end

  defp query_objects(filter_spec, _) do
    query = from o in Photo, as: :object

    query = case filter_spec["album"] do
              nil -> query
              id -> from o in Photo, as: :object,
              join: album in assoc(o, :albums),
              where: album.id == ^id
            end

    case filter_spec["query"] do
      nil -> query
      search -> from o in query, where: fragment("to_tsvector(?) @@ to_tsquery(?)", o.title, ^search)
    end
  end

  @spec query_object(integer) :: Ecto.Query.t()
  defp query_object(id) do
    from o in Photo,
      as: :object,
      where: o.id == ^id
  end

  @spec query_icons(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  defp query_icons(query, size) do
    file_query = from f in File,
      where: f.size_key == ^size and f.is_video == false,
      distinct: f.photo_id,
      order_by: [asc: :id]

    query = from o in query,
      left_join: f in subquery(file_query), on: f.photo_id == o.id, as: :file,
      select: %{id: o.id, title: o.title, datetime: o.datetime, utc_offset: o.utc_offset, dir: f.dir, name: f.name, height: f.height, width: f.width, action: o.action},
      order_by: [asc: o.datetime, asc: o.id]

    query
  end

  @spec get_icon_from_result(map()) :: Objects.Icon.t()
  defp get_icon_from_result(result) do
    url = if result.dir do
      "https://photos.linuxpenguins.xyz/images/#{result.dir}/#{result.name}"
    end
    subtitle = Objects.display_datetime_offset(result.datetime, result.utc_offset)

    %Objects.Icon{
      id: result.id,
      action: result.action,
      url: url,
      title: result.title,
      subtitle: subtitle,
      height: result.height,
      width: result.width,
    }
  end

  @impl Objects
  @spec get_parent_ids(integer) :: list(integer())
  def get_parent_ids(id) when is_integer(id) do
    query = from o in Photo,
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
    query = from o in Photo,
      where: o.parent_id == ^id,
      select: o.id

    Repo.all(query)
  end

  @impl Objects
  @spec get_index(integer) :: list(MapSet.t())
  def get_index(_id) do
    []
  end

  @impl Objects
  @spec create_index(integer, {integer, integer}) :: :ok
  def create_index(_id, _index) do
    :ok
  end

  @impl Objects
  @spec delete_index(integer, {integer, integer}) :: :ok
  def delete_index(_id, _index) do
    :ok
  end

  @impl Objects
  @spec get_update_fields() :: list(Objects.Field.t())
  def get_update_fields do
    [
      %Objects.Field{
        id: :title,
        title: "Title",
        display: nil,
        type: :string,
      },
      %Objects.Field{
        id: :photographer_id,
        title: "Photographer",
        display: nil,
        type: :person,
      },
      %Objects.Field{
        id: :action,
        title: "Action",
        display: nil,
        type: :string,
      }
    ]
  end

  @impl Objects
  @spec get_parents(integer) :: list({Objects.Icon.t(), integer})
  def get_parents(_id) do
    []
  end

  @impl Objects
  @spec get_details(integer) :: {map(), Objects.Icon.t(), list(Objects.Field.t())} | nil
  def get_details(id) do
    query = id
    |> query_object()
    |> query_icons("mid")
    |> select_merge([object: o], %{o: o})

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
            id: :photographer_id,
            title: "Photographer",
            display: result.o.photographer_id,
            type: :person,
          },
          %Objects.Field{
            id: :action,
            title: "Action",
            display: result.o.action,
            type: :string,
          }
        ]
        {result.o, icon, fields}
    end
  end

  @impl Objects
  @spec get_page_icons(%{required(String.t()) => String.t()}, MapSet.t()|nil, String.t()|nil, String.t()|nil) :: {list(Objects.Icon.t), String.t()|nil, String.t()|nil, integer}
  def get_page_icons(filter_spec, ids, before_key, after_key) do
    query = filter_spec
    |> query_objects(ids)
    |> query_icons("thumb")

    %{entries: entries, metadata: metadata} = Repo.paginate(
      query, before: before_key, after: after_key,
      cursor_fields: [:datetime, :id],
      limit: 10
    )

    icons = Enum.map(entries, fn result ->
      get_icon_from_result(result)
    end)

    {icons, metadata.before, metadata.after, metadata.total_count}
  end


  @impl Objects
  @spec search_icons(%{required(String.t()) => String.t()}, MapSet.t()|nil, integer) :: list(Objects.Icon.t())
  def search_icons(filter_spec, ids, limit) do
    query = filter_spec
    |> query_objects(ids)
    |> query_icons("thumb")
    |> limit(^limit)

    entries = Repo.all(query)

    Enum.map(entries, fn result ->
      get_icon_from_result(result)
    end)
  end

  @impl Objects
  @spec get_create_child_changeset(Photo.t(), map()) :: Ecto.Changeset.t()
  def get_create_child_changeset(%Photo{} = album, attrs) do
    %Photo{}
    |> Photo.edit_changeset(attrs)
    |> Changeset.put_change(:parent_id, album.id)
  end

  @impl Objects
  @spec get_edit_changeset(map(), map()) :: Ecto.Changeset.t()
  def get_edit_changeset(album, attrs) do
    Photo.edit_changeset(album, attrs)
  end

  @impl Objects
  @spec get_update_changeset(MapSet.t(), map()) :: Ecto.Changeset.t()
  def get_update_changeset(enabled, attrs) do
    Photo.update_changeset(%Photo{}, enabled, attrs)
  end

  @impl Objects
  @spec has_parent_changed?(Changeset.t()) :: boolean
  def has_parent_changed?(%Changeset{data: %Photo{}} = _changeset) do
    false
  end

  @spec is_album_cover_photo?(integer) :: boolean
  def is_album_cover_photo?(id) do
    query = from o in Album, where: o.cover_photo_id == ^id
    Repo.exists?(query)
  end

  @impl Objects
  @spec can_delete?(integer) :: {:no, String.t()} | :yes
  def can_delete?(id) do
    cond do
      is_album_cover_photo?(id) ->
        {:no, "Cannot delete photo that is used by album cover photo"}
      true ->
        :yes
    end
  end

  @spec do_delete(Photo.t()) :: :ok | {:error, String.t()}
  defp do_delete(%Photo{} = object) do
    result = Multi.new()
    |> Multi.run(:object, fn _, _ ->
      object
      |> Ecto.Changeset.change(action: "D")
      |> Repo.update()
    end)
    |> Repo.transaction()

    case result do
      {:ok, _} -> :ok
      {:error, :object, _, _} ->
        {:error, "Cannot delete photo"}
    end
  end

  @impl Objects
  @spec delete(Photo.t()) :: :ok | {:error, String.t()}
  def delete(%Photo{} = object) do
    case can_delete?(object.id) do
      :yes -> do_delete(object)
      {:no, error} -> {:error, error}
    end
  end

  @impl Objects
  @spec get_photo_params(integer) :: map() | nil
  def get_photo_params(_id) do
    nil
  end

end
