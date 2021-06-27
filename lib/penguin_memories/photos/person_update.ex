defmodule PenguinMemories.Photos.PersonUpdate do
  @moduledoc "An update to a person"
  use Ecto.Schema

  @timestamps_opts [type: :utc_datetime_usec]

  @type t :: %__MODULE__{
          mother: t() | Ecto.Association.NotLoaded.t() | nil,
          father: t() | Ecto.Association.NotLoaded.t() | nil,
          spouse: t() | Ecto.Association.NotLoaded.t() | nil,
          home: t() | Ecto.Association.NotLoaded.t() | nil,
          work: t() | Ecto.Association.NotLoaded.t() | nil
        }

  embedded_schema do
    belongs_to :father, PenguinMemories.Photos.Person, on_replace: :nilify
    belongs_to :mother, PenguinMemories.Photos.Person, on_replace: :nilify
    belongs_to :spouse, PenguinMemories.Photos.Person, on_replace: :nilify
    belongs_to :home, PenguinMemories.Photos.Place, on_replace: :nilify
    belongs_to :work, PenguinMemories.Photos.Place, on_replace: :nilify
  end
end
