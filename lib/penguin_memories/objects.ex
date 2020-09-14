defmodule PenguinMemories.Objects do
  defmodule Icon do
    @type t :: %__MODULE__{
      url: String.t(),
      title: String.t(),
      width: integer,
      height: integer,
    }
    @enforce_keys [:url, :title, :width, :height]
    defstruct [:url, :title, :width, :height]
  end

  @callback get_plural_title() :: String.t()
  @callback get_icons(String.t()|nil, String.t()|nil) :: {list(Icon.t), String.t()|nil, String.t()|nil, integer}

  def get_for_type(type) do
    case type do
      "album" -> PenguinMemories.Objects.Album
    end
  end
end
