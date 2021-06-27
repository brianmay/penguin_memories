defmodule PenguinMemories.Photos.PlaceUpdate do
  @moduledoc "An update to a location"
  use Ecto.Schema

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          parent: t() | Ecto.Association.NotLoaded.t() | nil,
          revised: DateTime.t() | nil
        }

  embedded_schema do
    belongs_to :parent, PenguinMemories.Photos.Place, on_replace: :nilify
    field :revised, :utc_datetime
  end
end
