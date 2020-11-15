defmodule PenguinMemories.Photos.Photo do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  import PenguinMemories.Photos.Private
  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.PhotoAlbum
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Thumb
  alias PenguinMemories.Photos.Video

  @type t :: map()
  schema "spud_photo" do
    field :action, :string
    field :aperture, :string
    field :camera_make, :string
    field :camera_model, :string
    field :ccd_width, :string
    field :comment, :string
    field :compression, :string
    field :datetime, :utc_datetime
    field :description, :string
    field :exposure, :string
    field :flash_used, :string
    field :focal_length, :string
    field :focus_dist, :string
    field :iso_equiv, :string
    field :level, :integer
    field :metering_mode, :string
    field :name, :string
    field :path, :string
    field :photographer_id, :integer
    field :place_id, :integer
    field :rating, :float
    field :size, :integer
    field :timestamp, :utc_datetime
    field :title, :string
    field :utc_offset, :integer
    field :view, :string
    has_many :cover_photo_albums, Album, foreign_key: :cover_photo_id
    has_many :files, File
    has_many :thumbs, Thumb
    has_many :videos, Video

    field :album_list, :string, virtual: true
    has_many :photo_albums, PhotoAlbum, on_replace: :delete
    many_to_many :albums, Album, join_through: PhotoAlbum
  end

  @doc false
  def delete_changeset(photo, attrs) do
    photo
    |> cast(attrs, [
      :comment,
      :rating,
      :flash_used,
      :metering_mode,
      :datetime,
      :size,
      :compression,
      :title,
      :photographer_id,
      :place_id,
      :aperture,
      :ccd_width,
      :description,
      :timestamp,
      :iso_equiv,
      :focal_length,
      :path,
      :exposure,
      :namer,
      :level,
      :camera_make,
      :camera_model,
      :focus_dist,
      :action,
      :view,
      :utc_offset
    ])
    |> validate_required([
      :comment,
      :rating,
      :flash_used,
      :metering_mode,
      :datetime,
      :size,
      :compression,
      :title,
      :photographer_id,
      :place_id,
      :aperture,
      :ccd_width,
      :description,
      :timestamp,
      :iso_equiv,
      :focal_length,
      :path,
      :exposure,
      :namer,
      :level,
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
      case PenguinMemories.Objects.Photo.can_delete?(id) do
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
    case Enum.filter(photo_albums, fn pa -> pa.photo_id == photo_id and pa.album_id == album_id end) do
      [result] -> result
      [] -> %PhotoAlbum{}
    end
  end

  defp put_albums(%Ecto.Changeset{valid?: true, changes: %{album_list: album_list}} = changeset) do
    photo_id = fetch_field!(changeset, :id)
    photo_albums = fetch_field!(changeset, :photo_albums)

    case validate_list_ids(album_list) do
      {:ok, list} ->
        cs_list = Enum.map(list, fn album_id ->
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
      :comment,
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
end
