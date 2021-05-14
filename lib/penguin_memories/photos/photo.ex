defmodule PenguinMemories.Photos.Photo do
  @moduledoc "A single photo"
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  import PenguinMemories.Photos.Private
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Photos.PhotoRelation

  alias PenguinMemories.Objects.Photo

  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          id: integer | nil,
          action: String.t() | nil,
          aperture: float | nil,
          camera_make: String.t() | nil,
          camera_model: String.t() | nil,
          ccd_width: integer | nil,
          private_notes: String.t() | nil,
          datetime: DateTime.t() | nil,
          description: String.t() | nil,
          exposure_time: float | nil,
          flash_used: boolean | nil,
          focal_length: integer | nil,
          focus_dist: float | nil,
          iso_equiv: integer | nil,
          metering_mode: String.t() | nil,
          name: String.t() | nil,
          dir: String.t() | nil,
          photographer_id: integer | nil,
          place_id: integer | nil,
          rating: float | nil,
          title: String.t() | nil,
          view: String.t() | nil,
          utc_offset: integer() | nil,
          cover_photo_albums: list(Album.t()) | Ecto.Association.NotLoaded.t() | nil,
          files: list(File.t()) | Ecto.Association.NotLoaded.t() | nil,
          album_list: list(integer()) | Ecto.Association.NotLoaded.t() | nil,
          # photo_albums: list(PhotoAlbum.t()) | Ecto.Association.NotLoaded.t() | nil,
          albums: list(Album.t()) | Ecto.Association.NotLoaded.t() | nil,
          photo_relations: list(PhotoRelation.t()) | Ecto.Association.NotLoaded.t() | nil
        }

  schema "pm_photo" do
    field :action, :string
    field :aperture, :float
    field :camera_make, :string
    field :camera_model, :string
    field :ccd_width, :integer
    field :private_notes, :string
    field :datetime, :utc_datetime
    field :description, :string
    field :exposure_time, :float
    field :flash_used, :boolean
    field :focal_length, :float
    field :focus_dist, :float
    field :iso_equiv, :integer
    field :metering_mode, :string
    field :name, :string
    field :dir, :string
    field :photographer_id, :integer
    field :place_id, :integer
    field :rating, :float
    field :title, :string
    field :view, :string
    field :utc_offset, :integer
    has_many :cover_photo_albums, Album, foreign_key: :cover_photo_id
    has_many :files, File, on_replace: :delete

    field :album_list, :string, virtual: true
    # has_many :photo_albums, PhotoAlbum, on_replace: :delete
    many_to_many :albums, Album, join_through: PhotoAlbum
    has_many :photo_relations, PhotoRelation, foreign_key: :photo_id

    timestamps()
  end

  @doc false
  def delete_changeset(photo, attrs) do
    photo
    |> cast(attrs, [
      :private_notes,
      :rating,
      :flash_used,
      :metering_mode,
      :datetime,
      :title,
      :photographer_id,
      :place_id,
      :aperture,
      :ccd_width,
      :description,
      :timestamp,
      :iso_equiv,
      :focal_length,
      :dir,
      :exposure_time,
      :namer,
      :camera_make,
      :camera_model,
      :focus_dist,
      :action,
      :view,
      :utc_offset
    ])
    |> validate_required([
      :private_notes,
      :rating,
      :flash_used,
      :metering_mode,
      :datetime,
      :title,
      :photographer_id,
      :place_id,
      :aperture,
      :ccd_width,
      :description,
      :timestamp,
      :iso_equiv,
      :focal_length,
      :dir,
      :exposure_time,
      :namer,
      :camera_make,
      :camera_model,
      :focus_dist,
      :action,
      :view,
      :utc_offset
    ])
  end

  @spec validate_datetime(Changeset.t()) :: Changeset.t()
  defp validate_datetime(%Changeset{data: %__MODULE__{}} = changeset) do
    validate_pair(changeset, :datetime, :utc_offset)
  end

  @spec validate_delete(Changeset.t()) :: Changeset.t()
  defp validate_delete(changeset) do
    id = get_field(changeset, :id)

    if get_change(changeset, :action) == "D" do
      case Photo.can_delete?(id) do
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

  @spec get_photo_album(list(PhotoAlbum.t()), integer(), integer()) :: PhotoAlbum.t()
  defp get_photo_album(photo_albums, photo_id, album_id) do
    case Enum.filter(photo_albums, fn pa ->
           pa.photo_id == photo_id and pa.album_id == album_id
         end) do
      [result] -> result
      [] -> %PhotoAlbum{}
    end
  end

  defp put_albums(%Ecto.Changeset{valid?: true, changes: %{album_list: album_list}} = changeset) do
    photo_id = fetch_field!(changeset, :id)
    photo_albums = fetch_field!(changeset, :photo_albums)

    case validate_list_ids(album_list) do
      {:ok, list} ->
        cs_list =
          Enum.map(list, fn album_id ->
            pa = get_photo_album(photo_albums, photo_id, album_id)
            PhotoAlbum.changeset(pa, %{photo_id: photo_id, album_id: album_id})
          end)

        put_assoc(changeset, :photo_albums, cs_list)

      {:error, msg} ->
        add_error(changeset, :album_list, msg)
    end
  end

  defp put_albums(changeset), do: changeset

  @spec edit_changeset(t(), map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = photo, attrs) do
    photo
    |> cast(attrs, [
      :title,
      :photographer_id,
      :place_id,
      :view,
      :rating,
      :description,
      :datetime,
      :utc_offset,
      :action,
      :private_notes,
      :album_list
    ])
    |> validate_action()
    |> validate_delete()
    |> validate_datetime()
    |> put_albums()
  end

  @spec update_changeset(t(), MapSet.t(), map()) :: Changeset.t()
  def update_changeset(%__MODULE__{} = photo, enabled, attrs) do
    allowed_list = [
      :title,
      :photographer_id,
      :place_id,
      :view,
      :rating,
      :description,
      :datetime,
      :utc_offset,
      :action
    ]

    allowed = MapSet.new(allowed_list)
    enabled = MapSet.intersection(enabled, allowed)
    enabled_list = MapSet.to_list(enabled)

    changeset =
      photo
      |> cast(attrs, enabled_list)
      |> validate_datetime()

    if MapSet.member?(enabled, :action) do
      validate_action(changeset)
    else
      changeset
    end
  end

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = photo) do
    "#{photo.id}:#{photo.dir}/#{photo.name}"
  end
end
