defmodule PenguinMemories.Photos.File do
  @moduledoc "A file for a photo"
  use Ecto.Schema
  import Ecto.Changeset

  alias PenguinMemories.Photos.Photo

  @timestamps_opts [type: :utc_datetime]

  @type t :: %__MODULE__{
          dir: String.t(),
          height: integer(),
          is_video: boolean(),
          mime_type: String.t(),
          name: String.t(),
          num_bytes: integer(),
          sha256_hash: binary(),
          size_key: String.t(),
          width: integer(),
          photo_id: integer(),
          photo: Photo.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_photo_file" do
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
    timestamps()
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

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = file) do
    "#{file.id}:#{file.dir}/#{file.name}"
  end
end
