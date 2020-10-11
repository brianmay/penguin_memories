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
    many_to_many :albums, PenguinMemories.Photos.Album, join_through: PhotoAlbum
  end

  @doc false
  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [:comment, :rating, :flash_used, :metering_mode, :datetime, :size, :compression, :title, :photographer_id, :place_id, :aperture, :ccd_width, :description, :timestamp, :iso_equiv, :focal_length, :path, :exposure, :namer, :level, :camera_make, :camera_model, :focus_dist, :action, :view, :utc_offset])
    |> validate_required([:comment, :rating, :flash_used, :metering_mode, :datetime, :size, :compression, :title, :photographer_id, :place_id, :aperture, :ccd_width, :description, :timestamp, :iso_equiv, :focal_length, :path, :exposure, :namer, :level, :camera_make, :camera_model, :focus_dist, :action, :view, :utc_offset])
  end

  @spec validate_datetime(Changeset.t()) :: Changeset.t()
  defp validate_datetime(%Changeset{data: %__MODULE__{}} = changeset) do
    validate_pair(changeset, :datetime, :utc_offset)
  end

  @spec validate_action(Changeset.t()) :: Changeset.t()
  defp validate_action(changeset) do
    validate_inclusion(changeset, :action, ["D", "R", "M", "auto", "90", "180", "270"])
  end

  @spec edit_changeset(t(), map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = photo, attrs) do
    photo
    |> cast(attrs, [:title, :photographer_id, :action])
    |> validate_required([:title])
    |> validate_action()
    |> validate_datetime()
  end

  @spec update_changeset(t(), MapSet.t(), map()) :: Changeset.t()
  def update_changeset(%__MODULE__{} = photo, enabled, attrs) do
    allowed_list = [:title, :photographer_id, :action]
    allowed = MapSet.new(allowed_list)
    enabled = MapSet.intersection(enabled, allowed)
    enabled_list = MapSet.to_list(enabled)
    required = MapSet.new([:title])
    required_list = MapSet.to_list(
      MapSet.intersection(enabled, required)
    )

    changeset = photo
    |> cast(attrs, enabled_list)
    |> validate_required(required_list)
    |> validate_datetime()

    if MapSet.member?(enabled, :action) do
      validate_action(changeset)
    else
      changeset
    end
  end

end
