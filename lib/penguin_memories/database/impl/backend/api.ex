defmodule PenguinMemories.Database.Impl.Backend.API do
  @moduledoc """
  Backend API used for object types
  """
  alias Ecto.Changeset
  alias PenguinMemories.Database
  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemories.Database.Fields.UpdateField
  alias PenguinMemories.Database.Query.Details

  @callback get_single_name :: String.t()
  @callback get_plural_name :: String.t()
  @callback get_cursor_fields :: list(atom())
  @callback get_parent_fields() :: list(atom())
  @callback get_parent_id_fields() :: list(atom())
  @callback get_index_type() :: module() | nil
  @callback query() :: Ecto.Query.t()
  @callback filter_by_photo_id(query :: Ecto.Query.t(), photo_id :: integer) :: Ecto.Query.t()
  @callback filter_by_parent_id(query :: Ecto.Query.t(), parent_id :: integer) :: Ecto.Query.t()
  @callback filter_by_reference(query :: Ecto.Query.t(), reference :: Database.reference_type()) ::
              Ecto.Query.t()
  @callback preload_details(query :: Ecto.Query.t()) :: Ecto.Query.t()
  @callback preload_details_from_results(list(struct())) :: list(struct())
  @callback get_title_from_result(result :: map()) :: String.t()
  @callback get_subtitle_from_result(result :: map()) :: String.t() | nil
  @callback get_details_from_result(
              result :: map(),
              icon_size :: String.t(),
              video_size :: String.t()
            ) :: Details.t()

  @callback get_fields() :: list(Field.t())
  @callback get_update_fields() :: list(UpdateField.t())

  @callback edit_changeset(object :: struct(), attrs :: map(), assoc :: map()) :: Changeset.t()
  @callback update_changeset(
              object :: struct(),
              attrs :: map(),
              assoc :: map(),
              enabled :: MapSet.t()
            ) ::
              Changeset.t()
end
