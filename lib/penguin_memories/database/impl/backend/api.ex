defmodule PenguinMemories.Database.Impl.Backend.API do
  @moduledoc """
  Backend API used for object types
  """
  alias PenguinMemories.Database.Query.Details
  alias PenguinMemories.Database.Query.Field

  @callback get_single_name :: String.t()
  @callback get_plural_name :: String.t()
  @callback get_cursor_fields :: list(atom())
  @callback get_parent_fields() :: list(atom())
  @callback get_index_type() :: module() | nil
  @callback query() :: Ecto.Query.t()
  @callback filter_by_photo_id(query :: Ecto.Query.t(), photo_id :: integer) :: Ecto.Query.t()
  @callback filter_by_parent_id(query :: Ecto.Query.t(), parent_id :: integer) :: Ecto.Query.t()
  @callback filter_by_reference(query :: Ecto.Query.t(), reference :: {module(), integer()}) ::
              Ecto.Query.t()
  @callback get_subtitle_from_result(result :: map()) :: String.t()
  @callback get_details_from_result(
              result :: map(),
              icon_size :: String.t(),
              video_size :: String.t()
            ) :: Details.t()
  @callback get_update_fields :: list(Field.t())
end
