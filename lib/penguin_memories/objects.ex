defmodule PenguinMemories.Objects do
  defmodule Icon do
    @type t :: %__MODULE__{
      id: integer,
      url: String.t(),
      title: String.t(),
      width: integer,
      height: integer,
    }
    @enforce_keys [:id, :url, :title, :width, :height]
    defstruct [:id, :url, :title, :width, :height]
  end

  @callback get_plural_title() :: String.t()
  @callback get_icons(%{required(String.t()) => String.t()}, String.t()|nil, String.t()|nil) :: {list(Icon.t), String.t()|nil, String.t()|nil, integer}

  def get_for_type(type) do
    case type do
      "album" -> PenguinMemories.Objects.Album
    end
  end
end
