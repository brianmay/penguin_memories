defmodule PenguinMemories.Photos.File do
  use Ecto.Schema
  import Ecto.Changeset

  alias PenguinMemories.Photos.Photo

  schema "spud_photo_file" do
    field :dir, :string
    field :height, :integer
    field :is_video, :boolean, default: false
    field :mime_type, :string
    field :name, :string
    field :num_bytes, :integer
    field :sha256_hash, :binary
    field :size_key, :string
    field :width, :integer
    belongs_to :photo, Photo
  end

  @doc false
  def changeset(file, attrs) do
    file
    |> cast(attrs, [
      :size_key,
      :width,
      :height,
      :dir,
      :name,
      :is_video,
      :mime_type,
      :sha256_hash,
      :num_bytes
    ])
    |> validate_required([
      :size_key,
      :width,
      :height,
      :dir,
      :name,
      :is_video,
      :mime_type,
      :sha256_hash,
      :num_bytes
    ])
  end
end
