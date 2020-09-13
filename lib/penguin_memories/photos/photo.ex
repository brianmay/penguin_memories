defmodule PenguinMemories.Photos.Photo do
  use Ecto.Schema
  import Ecto.Changeset

  alias PenguinMemories.Photos.Album
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Thumb
  alias PenguinMemories.Photos.Video

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
    has_many :albums, Album, foreign_key: :cover_photo_id
    has_many :files, File
    has_many :thumbs, Thumb
    has_many :videos, Video
  end

  @doc false
  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [:comment, :rating, :flash_used, :metering_mode, :datetime, :size, :compression, :title, :photographer_id, :place_id, :aperture, :ccd_width, :description, :timestamp, :iso_equiv, :focal_length, :path, :exposure, :namer, :level, :camera_make, :camera_model, :focus_dist, :action, :view, :utc_offset])
    |> validate_required([:comment, :rating, :flash_used, :metering_mode, :datetime, :size, :compression, :title, :photographer_id, :place_id, :aperture, :ccd_width, :description, :timestamp, :iso_equiv, :focal_length, :path, :exposure, :namer, :level, :camera_make, :camera_model, :focus_dist, :action, :view, :utc_offset])
  end
end
