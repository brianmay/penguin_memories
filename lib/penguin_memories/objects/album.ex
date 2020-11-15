defmodule PenguinMemories.Objects.Album do
  @moduledoc """
  Album specific functions.
  """
  import Ecto.Query
  alias Ecto.Changeset
  alias Ecto.Multi

  alias PenguinMemories.Repo
  alias PenguinMemories.Objects
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.AlbumAscendant
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Photos.File

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

  @spec query_objects(%{required(String.t()) => String.t()}) :: Ecto.Query.t()
  defp query_objects(%{"ids" => id_mapset}) when not is_nil(id_mapset) do
    id_list = MapSet.to_list(id_mapset)

    from o in Album,
      as: :object,
      where: o.id in ^id_list
  end

  defp query_objects(filter_spec) do
    query = from o in Album, as: :object

    query =
      case filter_spec["photo_id"] do
        nil ->
          query

        id ->
          from o in query,
            join: op in PhotoAlbum,
            on: op.album_id == o.id,
            where: op.photo_id == ^id
      end

    query =
      case filter_spec["parent_id"] do
        nil -> query
        id -> from o in query, where: o.parent_id == ^id
      end

    case filter_spec["query"] do
      nil ->
        query

      search ->
        filtered_search = ["%", String.replace(search, "%", ""), "%"]
        filtered_search = Enum.join(filtered_search)
        dynamic = dynamic([o], ilike(o.title, ^filtered_search))

        dynamic =
          case Integer.parse(search) do
            {int, ""} -> dynamic([o], ^dynamic or o.id == ^int)
            _ -> dynamic
          end

        from o in query, where: ^dynamic
    end
  end

  @spec query_ascendants(integer) :: Ecto.Query.t()
  defp query_ascendants(id) do
    from o in Album,
      as: :object,
      join: oa in AlbumAscendant,
      on: o.id == oa.ascendant_id,
      as: :ascendants,
      where: oa.descendant_id == ^id
  end

  @spec query_object(integer) :: Ecto.Query.t()
  defp query_object(id) do
    from o in Album,
      as: :object,
      where: o.id == ^id
  end

  @spec query_add_parents(Ecto.Query.t()) :: Ecto.Query.t()
  defp query_add_parents(query) do
    from o in query, left_join: op in Album, on: o.parent_id == op.id, as: :parent
  end

  @spec query_icons(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  defp query_icons(query, size) do
    file_query =
      from f in File,
        where: f.size_key == ^size and f.is_video == false,
        distinct: f.photo_id,
        order_by: [asc: :id]

    query =
      from o in query,
        left_join: p in Photo,
        on: p.id == o.cover_photo_id,
        as: :photo,
        left_join: f in subquery(file_query),
        on: f.photo_id == p.id,
        as: :file,
        select: %{
          id: o.id,
          title: o.title,
          sort_name: o.sort_name,
          sort_order: o.sort_order,
          dir: f.dir,
          name: f.name,
          height: f.height,
          width: f.width
        },
        order_by: [asc: o.sort_name, asc: o.sort_order, asc: o.id]

    query
  end

  @spec get_icon_from_result(map()) :: Objects.Icon.t()
  defp get_icon_from_result(result) do
    url =
      if result.dir do
        "https://photos.linuxpenguins.xyz/images/#{result.dir}/#{result.name}"
      end

    subtitle =
      if result.sort_name != "" and result.sort_order != "" do
        "#{result.sort_name}: #{result.sort_order}"
      end

    %Objects.Icon{
      id: result.id,
      action: nil,
      url: url,
      title: result.title,
      subtitle: subtitle,
      height: result.height,
      width: result.width,
      type: __MODULE__
    }
  end

  @impl Objects
  @spec get_parent_ids(integer) :: list(integer())
  def get_parent_ids(id) when is_integer(id) do
    query =
      from o in Album,
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
    query =
      from o in Album,
        where: o.parent_id == ^id,
        select: o.id

    Repo.all(query)
  end

  @impl Objects
  @spec get_index(integer) :: list(MapSet.t())
  def get_index(id) do
    query =
      from oa in AlbumAscendant,
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

    Repo.insert!(%AlbumAscendant{
      ascendant_id: referenced_id,
      descendant_id: id,
      position: position
    })

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
  @spec get_update_fields() :: list(Objects.Field.t())
  def get_update_fields do
    [
      %Objects.Field{
        id: :title,
        title: "Title",
        display: nil,
        type: :string
      },
      %Objects.Field{
        id: :parent_id,
        title: "Parent",
        display: nil,
        type: :album
      },
      %Objects.Field{
        id: :sort_name,
        title: "Sort Name",
        display: nil,
        type: :string
      },
      %Objects.Field{
        id: :sort_order,
        title: "Sort Order",
        display: nil,
        type: :string
      },
      %Objects.Field{
        id: :revised,
        title: "Revised time",
        display: nil,
        type: :datetime
      },
      %Objects.Field{
        id: :revised,
        title: "Revised UTC offset",
        display: nil,
        type: :string
      }
    ]
  end

  @impl Objects
  @spec get_parents(integer) :: list({Objects.Icon.t(), integer})
  def get_parents(id) do
    query =
      id
      |> query_ascendants()
      |> query_icons("thumb")
      |> select_merge([ascendants: oa], %{position: oa.position})

    icons =
      Enum.map(Repo.all(query), fn result ->
        {get_icon_from_result(result), result.position}
      end)

    icons
  end

  @impl Objects
  @spec get_details(integer) ::
          {map(), Objects.Icon.t(), list(Objects.Field.t()), String.t()} | nil
  def get_details(id) do
    query =
      id
      |> query_object()
      |> query_add_parents()
      |> query_icons("mid")
      |> select_merge([object: o, photo: p, parent: op], %{
        o: o
      })

    case Repo.one(query) do
      nil ->
        nil

      result ->
        icon = get_icon_from_result(result)
        parent_icons = search_icons(%{"ids" => MapSet.new([result.o.parent_id])}, 1)

        cover_icons =
          PenguinMemories.Objects.Photo.search_icons(
            %{"ids" => MapSet.new([result.o.cover_photo_id])},
            1
          )

        fields = [
          %Objects.Field{
            id: :title,
            title: "Title",
            display: result.o.title,
            type: :string
          },
          %Objects.Field{
            id: :parent_id,
            title: "Parent",
            display: nil,
            icons: parent_icons,
            type: :album
          },
          %Objects.Field{
            id: :description,
            title: "Description",
            display: result.o.description,
            type: :markdown
          },
          %Objects.Field{
            id: :cover_photo_id,
            title: "Cover Photo",
            display: nil,
            icons: cover_icons,
            type: :photo
          },
          %Objects.Field{
            id: :sort_name,
            title: "Sort Name",
            display: result.o.sort_name,
            type: :string
          },
          %Objects.Field{
            id: :sort_order,
            title: "Sort Order",
            display: result.o.sort_order,
            type: :string
          },
          %Objects.Field{
            id: :revised,
            title: "Revised time",
            display:
              Objects.display_datetime_offset(result.o.revised, result.o.revised_utc_offset),
            type: :datetime
          },
          %Objects.Field{
            id: :revised_utc_offset,
            title: "Revised UTC offset",
            display: result.o.revised_utc_offset,
            type: :string
          }
        ]

        cursor = Paginator.cursor_for_record(result, [:sort_name, :sort_order, :id])
        {result.o, icon, fields, cursor}
    end
  end

  @impl Objects
  @spec get_page_icons(
          %{required(String.t()) => String.t()},
          String.t() | nil,
          String.t() | nil,
          integer()
        ) :: {list(Objects.Icon.t()), String.t() | nil, String.t() | nil, integer}
  def get_page_icons(filter_spec, before_key, after_key, limit) do
    query =
      filter_spec
      |> query_objects()
      |> query_icons("thumb")

    %{entries: entries, metadata: metadata} =
      Repo.paginate(
        query,
        before: before_key,
        after: after_key,
        cursor_fields: [:sort_name, :sort_order, :id],
        limit: limit
      )

    icons =
      Enum.map(entries, fn result ->
        get_icon_from_result(result)
      end)

    {icons, metadata.before, metadata.after, metadata.total_count}
  end

  @impl Objects
  @spec search_icons(%{required(String.t()) => String.t()}, integer) :: list(Objects.Icon.t())
  def search_icons(filter_spec, limit) do
    query =
      filter_spec
      |> query_objects()
      |> query_icons("thumb")
      |> limit(^limit)

    entries = Repo.all(query)

    Enum.map(entries, fn result ->
      get_icon_from_result(result)
    end)
  end

  @impl Objects
  @spec can_create?() :: boolean()
  def can_create?(), do: true

  @impl Objects
  @spec get_create_child_changeset(Album.t(), map()) :: Ecto.Changeset.t()
  def get_create_child_changeset(%Album{} = album, attrs) do
    %Album{}
    |> Album.edit_changeset(attrs)
    |> Changeset.put_change(:parent_id, album.id)
  end

  @impl Objects
  @spec get_edit_changeset(map(), map()) :: Ecto.Changeset.t()
  def get_edit_changeset(album, attrs) do
    Album.edit_changeset(album, attrs)
  end

  @impl Objects
  @spec get_update_changeset(MapSet.t(), map()) :: Ecto.Changeset.t()
  def get_update_changeset(enabled, attrs) do
    Album.update_changeset(%Album{}, enabled, attrs)
  end

  @impl Objects
  @spec has_parent_changed?(Changeset.t()) :: boolean
  def has_parent_changed?(%Changeset{data: %Album{}} = changeset) do
    case Changeset.fetch_change(changeset, :parent_id) do
      :error -> false
      {:ok, _value} -> true
    end
  end

  @impl Objects
  @spec can_delete?(integer) :: {:no, String.t()} | :yes
  def can_delete?(id) do
    cond do
      length(get_child_ids(id)) > 0 ->
        {:no, "Cannot delete object with child"}

      true ->
        :yes
    end
  end

  @spec do_delete(Album.t()) :: :ok | {:error, String.t()}
  defp do_delete(%Album{} = object) do
    result =
      Multi.new()
      |> Multi.delete_all(
        :index1,
        from(obj in AlbumAscendant, where: obj.ascendant_id == ^object.id)
      )
      |> Multi.delete_all(
        :index2,
        from(obj in AlbumAscendant, where: obj.descendant_id == ^object.id)
      )
      |> Multi.run(:object, fn _, _ -> Repo.delete(object) end)
      |> Repo.transaction()

    case result do
      {:ok, _} ->
        :ok

      {:error, :index1, _, _} ->
        {:error, "Cannot index 1"}

      {:error, :index2, _, _} ->
        {:error, "Cannot index 2"}

      {:error, :object, _, _} ->
        {:error, "Cannot delete album"}
    end
  end

  @impl Objects
  @spec delete(Album.t()) :: :ok | {:error, String.t()}
  def delete(%Album{} = object) do
    case can_delete?(object.id) do
      :yes -> do_delete(object)
      {:no, error} -> {:error, error}
    end
  end

  @impl Objects
  @spec get_photo_params(integer) :: map() | nil
  def get_photo_params(id) do
    %{
      "album" => id
    }
  end
end
