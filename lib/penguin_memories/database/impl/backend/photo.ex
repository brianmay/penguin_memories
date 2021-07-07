defmodule PenguinMemories.Database.Impl.Backend.Photo do
  @moduledoc """
  Backend Photo functions
  """
  alias Ecto.Changeset
  import Ecto.Changeset
  import Ecto.Query

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Fields.UpdateField
  alias PenguinMemories.Database.Impl.Backend.API
  alias PenguinMemories.Database.Impl.Backend.Private
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Format
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Photos.PhotoUpdate
  alias PenguinMemories.Photos.Relation
  alias PenguinMemories.Repo

  @behaviour API

  @impl API
  @spec get_single_name :: String.t()
  def get_single_name, do: "photo"

  @impl API
  @spec get_plural_name :: String.t()
  def get_plural_name, do: "photos"

  @impl API
  @spec get_cursor_fields :: list(atom())
  def get_cursor_fields, do: [:datetime, :id]

  @impl API
  @spec get_parent_fields :: list(atom())
  def get_parent_fields, do: []

  @impl API
  @spec get_parent_id_fields :: list(atom())
  def get_parent_id_fields, do: []

  @impl API
  @spec get_index_type :: module() | nil
  def get_index_type, do: nil

  @impl API
  @spec query :: Ecto.Query.t()
  def query do
    from o in Photo,
      as: :object,
      select: %{
        datetime: o.datetime,
        id: o.id,
        o: %{action: o.action, name: o.name, filename: o.filename, utc_offset: o.utc_offset}
      },
      order_by: [asc: o.datetime, asc: o.id]
  end

  @impl API
  @spec filter_by_photo_id(query :: Ecto.Query.t(), photo_id :: integer) :: Ecto.Query.t()
  def filter_by_photo_id(%Ecto.Query{} = query, photo_id) do
    from [object: o] in query,
      where: o.id == ^photo_id
  end

  @impl API
  @spec filter_by_parent_id(query :: Ecto.Query.t(), parent_id :: integer) :: Ecto.Query.t()
  def filter_by_parent_id(%Ecto.Query{} = query, _) do
    query
  end

  @impl API
  @spec filter_by_reference(query :: Ecto.Query.t(), reference :: {module(), integer()}) ::
          Ecto.Query.t()
  def filter_by_reference(%Ecto.Query{} = query, {PenguinMemories.Photos.Album, id}) do
    from [object: o] in query,
      join: op in PenguinMemories.Photos.PhotoAlbum,
      on: op.photo_id == o.id,
      where: op.album_id == ^id
  end

  def filter_by_reference(%Ecto.Query{} = query, {PenguinMemories.Photos.Category, id}) do
    from [object: o] in query,
      join: op in PenguinMemories.Photos.PhotoCategory,
      on: op.photo_id == o.id,
      where: op.category_id == ^id
  end

  def filter_by_reference(%Ecto.Query{} = query, {PenguinMemories.Photos.Person, id}) do
    from [object: o] in query,
      join: op in PenguinMemories.Photos.PhotoPerson,
      on: op.photo_id == o.id,
      where: op.person_id == ^id
  end

  def filter_by_reference(%Ecto.Query{} = query, {PenguinMemories.Photos.Place, id}) do
    from [object: o] in query,
      where: o.place_id == ^id
  end

  def filter_by_reference(%Ecto.Query{} = query, _) do
    query
  end

  @impl API
  @spec preload_details(query :: Ecto.Query.t()) :: Ecto.Query.t()
  def preload_details(query) do
    pp_query = from pp in PenguinMemories.Photos.PhotoPerson, order_by: pp.position

    query
    |> preload([:albums, :categorys, :place, :photographer])
    |> preload(photo_persons: ^pp_query)
  end

  @impl API
  @spec preload_details_from_results(results :: list(struct())) :: list(struct())
  def preload_details_from_results(results) do
    pp_query = from pp in PenguinMemories.Photos.PhotoPerson, order_by: pp.position

    results
    |> Repo.preload([:albums, :categorys, :place, :photographer])
    |> Repo.preload(photo_persons: pp_query)
  end

  @impl API
  @spec get_title_from_result(result :: map()) :: String.t()
  def get_title_from_result(%{} = result) do
    case result.o.name do
      nil -> result.o.filename
      name -> name
    end
  end

  @impl API
  @spec get_subtitle_from_result(result :: map()) :: String.t() | nil
  def get_subtitle_from_result(%{} = result) do
    Format.display_datetime_offset(result.datetime, result.o.utc_offset)
  end

  @impl API
  @spec get_details_from_result(
          result :: map(),
          icon_size :: String.t(),
          video_size :: String.t()
        ) :: Query.Details.t()
  def get_details_from_result(%{} = result, _icon_size, video_size) do
    icon = Query.get_icon_from_result(result, Photo)
    orig = Query.get_orig_from_result(result, Photo)
    videos = Query.get_videos_for_photo(result.o.id, video_size)

    related =
      from(r in Relation,
        join: pr1 in PenguinMemories.Photos.PhotoRelation,
        on: pr1.relation_id == r.id,
        join: pr2 in PenguinMemories.Photos.PhotoRelation,
        on: pr2.relation_id == r.id,
        where: pr1.photo_id == ^result.id,
        select: %{r: r, pr: pr2}
      )
      |> Repo.all()

    o = %Photo{result.o | related: related}
    cursor = Paginator.cursor_for_record(result, get_cursor_fields())

    %Query.Details{
      obj: o,
      icon: icon,
      orig: orig,
      videos: videos,
      cursor: cursor,
      type: Photo
    }
  end

  @impl API
  @spec get_fields :: list(Field.t())
  def get_fields do
    [
      %Field{
        id: :id,
        name: "ID",
        type: :integer,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :name,
        name: "Name",
        type: :string,
        searchable: true
      },
      %Field{
        id: :dir,
        name: "Directory",
        type: :string,
        read_only: true
      },
      %Field{
        id: :filename,
        name: "File Name",
        type: :string,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :albums,
        name: "Albums",
        type: {:multiple, PenguinMemories.Photos.Album},
        searchable: true
      },
      %Field{
        id: :categorys,
        name: "Categories",
        type: {:multiple, PenguinMemories.Photos.Category},
        searchable: true
      },
      %Field{
        id: :place,
        name: "Place",
        type: {:single, PenguinMemories.Photos.Place},
        searchable: true
      },
      %Field{
        id: :photographer,
        name: "Photographer",
        type: {:single, PenguinMemories.Photos.Person},
        searchable: true
      },
      %Field{
        id: :photo_persons,
        name: "People",
        type: :persons,
        searchable: true
      },
      %Field{
        id: :related,
        name: "Related",
        type: :related,
        read_only: true
      },
      %Field{
        id: :view,
        name: "View",
        type: :string
      },
      %Field{
        id: :rating,
        name: "Rating",
        type: :float,
        searchable: true
      },
      %Field{
        id: :description,
        name: "Description",
        type: :markdown
      },
      %Field{
        id: :private_notes,
        name: "Private Notes",
        type: :markdown,
        access: :private
      },
      %Field{
        id: :datetime,
        name: "Time",
        type: {:datetime_with_offset, :utc_offset},
        searchable: true
      },
      %Field{
        id: :utc_offset,
        name: "UTC offset",
        type: :utc_offset,
        searchable: true
      },
      %Field{
        id: :action,
        name: "Action",
        type: :string,
        searchable: true
      },
      %Field{
        id: :camera_make,
        name: "Camera Make",
        type: :string,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :camera_model,
        name: "Camera Model",
        type: :string,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :flash_used,
        name: "Flash Used",
        type: :boolean,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :focal_length,
        name: "Focal Length",
        type: :float,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :exposure_time,
        name: "Exposure Time",
        type: :float,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :aperture,
        name: "Aperture",
        type: :float,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :iso_equiv,
        name: "ISO",
        type: :integer,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :metering_mode,
        name: "Metering Mode",
        type: :string,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :focus_dist,
        name: "Focus Distance",
        type: :string,
        read_only: true,
        searchable: true
      },
      %Field{
        id: :ccd_width,
        name: "CCD Width",
        type: :string,
        read_only: true,
        searchable: true
      }
    ]
  end

  @impl API
  @spec get_update_fields() :: list(UpdateField.t())
  def get_update_fields do
    [
      %UpdateField{
        id: :name,
        field_id: :name,
        name: "Name",
        type: :string,
        change: :set
      },
      %UpdateField{
        id: :photographer,
        field_id: :photographer,
        name: "Photographer",
        type: {:single, PenguinMemories.Photos.Person},
        change: :set
      },
      %UpdateField{
        id: :place,
        field_id: :place,
        name: "Place",
        type: {:single, PenguinMemories.Photos.Place},
        change: :set
      },
      %UpdateField{
        id: :album_add,
        field_id: :albums,
        name: "Album Add",
        type: {:multiple, PenguinMemories.Photos.Album},
        change: :add
      },
      %UpdateField{
        id: :album_delete,
        field_id: :albums,
        name: "Album Delete",
        type: {:multiple, PenguinMemories.Photos.Album},
        change: :delete
      },
      %UpdateField{
        id: :category_add,
        field_id: :categorys,
        name: "Category Add",
        type: {:multiple, PenguinMemories.Photos.Category},
        change: :add
      },
      %UpdateField{
        id: :category_delete,
        field_id: :categorys,
        name: "Category Delete",
        type: {:multiple, PenguinMemories.Photos.Category},
        change: :delete
      },
      %UpdateField{
        id: :view,
        field_id: :view,
        name: "View",
        type: :string,
        change: :set
      },
      %UpdateField{
        id: :rating,
        field_id: :rating,
        name: "Rating",
        type: :float,
        change: :set
      },
      %UpdateField{
        id: :datetime,
        field_id: :datetime,
        name: "Time",
        type: {:datetime_with_offset, :utc_offset},
        change: :set
      },
      %UpdateField{
        id: :utc_offset,
        field_id: :offset,
        name: "UTC offset",
        type: :utc_offset,
        change: :set
      },
      %UpdateField{
        id: :action,
        field_id: :action,
        name: "Action",
        type: :string,
        change: :set
      }
    ]
  end

  @spec validate_datetime(Changeset.t()) :: Changeset.t()
  defp validate_datetime(%Changeset{data: %Photo{}} = changeset) do
    Private.validate_pair(changeset, :datetime, :utc_offset)
  end

  @spec validate_delete(Changeset.t()) :: Changeset.t()
  defp validate_delete(changeset) do
    id = get_field(changeset, :id)

    if get_change(changeset, :action) == "D" do
      case Query.can_delete?(id, PenguinMemories.Photos.Photo) do
        :yes -> changeset
        {:no, error} -> add_error(changeset, :action, error)
      end
    else
      changeset
    end
  end

  @spec validate_action(Changeset.t()) :: Changeset.t()
  defp validate_action(changeset) do
    validate_inclusion(changeset, :action, ["D", "R", "M", "auto", "90", "180", "270"])
  end

  @impl API
  @spec edit_changeset(object :: Photo.t(), attrs :: map(), assoc :: map()) :: Changeset.t()
  def edit_changeset(%Photo{} = photo, attrs, assoc) do
    photo
    |> cast(attrs, [
      :name,
      :photographer_id,
      :view,
      :rating,
      :description,
      :datetime,
      :utc_offset,
      :action,
      :private_notes
    ])
    |> validate_action()
    |> validate_delete()
    |> validate_datetime()
    |> Private.put_all_assoc(assoc, [:albums, :categorys, :place, :photographer, :photo_persons])
  end

  @impl API
  @spec update_changeset(
          attrs :: map(),
          assoc :: map(),
          enabled :: MapSet.t()
        ) ::
          Changeset.t()
  def update_changeset(attrs, assoc, enabled) do
    %PhotoUpdate{
      photographer: nil,
      place: nil,
      album_add: [],
      album_delete: nil,
      category_add: nil,
      category_delete: nil
    }
    |> Private.selective_cast(attrs, enabled, [
      :name,
      :view,
      :rating,
      :datetime,
      :utc_offset,
      :action
    ])
    |> Private.selective_validate_required(enabled, [:name])
    |> Private.selective_put_assoc(assoc, enabled, [
      :photographer,
      :place,
      :album_add,
      :album_delete,
      :category_add,
      :category_delete
    ])
    |> validate_action()
    |> validate_delete()
  end
end
