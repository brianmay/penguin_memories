defmodule PenguinMemories.Photos.FileOrder do
  @moduledoc "A file for a photo"
  use Ecto.Schema

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          id: integer() | nil,
          size_key: String.t() | nil,
          mime_type: String.t() | nil,
          order: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "pm_photo_file_order" do
    field :size_key, :string
    field :mime_type, :string
    field :order, :integer
    timestamps()
  end
end
