defmodule PenguinMemories.Objects do
  defmodule Icon do
    @type t :: %__MODULE__{
      id: integer,
      action: String.t(),
      url: String.t(),
      title: String.t(),
      subtitle: String.t(),
      width: integer,
      height: integer,
    }
    @enforce_keys [:id, :action, :url, :title, :subtitle, :width, :height]
    defstruct [:id, :action, :url, :title, :subtitle, :width, :height]
  end

  defmodule Field do
    @type t :: %__MODULE__{
      id: atom,
      title: String.t(),
      display: String.t() | nil,
      type: :string|:markdown|:album|:photo|:time|:utc_offset
    }
    @enforce_keys [:id, :title, :display, :type]
    defstruct [:id, :title, :display, :type]
  end

  @callback get_type_name() :: String.t()
  @callback get_plural_title() :: String.t()
  @callback get_bulk_update_fields() :: list(Field.t())
  @callback get_parents(integer) :: {list(Objects.Icon.t())}
  @callback get_details(integer) :: {map(), Icon.t(), list(Field.t())} | nil
  @callback get_page_icons(%{required(String.t()) => String.t()}, MapSet.t()|nil, String.t()|nil, String.t()|nil) :: {list(Icon.t), String.t()|nil, String.t()|nil, integer}
  @callback get_icons(MapSet.t()|nil, integer()) :: list(Objects.Icon.t)


  def get_for_type(type) do
    case type do
      "album" -> PenguinMemories.Objects.Album
    end
  end
end
