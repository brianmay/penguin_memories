defmodule PenguinMemories.Database.Fields do
  @moduledoc """
  Generic database functions
  """
  alias PenguinMemories.Accounts.User
  alias PenguinMemories.Database
  alias PenguinMemories.Database.Types

  @type object_type :: Database.object_type()
  @type field_type ::
          :string
          | :markdown
          | :datetime
          | {:datetime_with_offset, atom()}
          | :utc_offset
          | {:single, object_type()}
          | {:multiple, object_type()}
          | :persons
          | :integer
          | :float
          | :boolean
  @type change_type :: :set | :add | :delete | nil

  defmodule Field do
    @moduledoc """
    A field specification that can be displayed or edited
    """
    @type object_type :: Database.object_type()
    @type field_type :: Database.Fields.field_type()

    @type t :: %__MODULE__{
            id: atom,
            name: String.t(),
            type: field_type(),
            read_only: boolean(),
            access: :private | :all,
            searchable: boolean()
          }
    @enforce_keys [:id, :name, :type]
    defstruct id: nil, name: nil, type: nil, read_only: false, access: :all, searchable: false
  end

  defmodule UpdateField do
    @moduledoc """
    A field specification for a bulk update field
    """
    @type object_type :: Database.object_type()
    @type change_type :: Database.Fields.change_type()
    @type field_type :: Database.Fields.field_type()

    @type t :: %__MODULE__{
            id: atom(),
            field_id: atom(),
            name: String.t(),
            type: field_type(),
            access: :private | :all,
            change: change_type
          }
    @enforce_keys [:id, :field_id, :name, :type, :change]
    defstruct id: nil, field_id: nil, name: nil, type: nil, access: :all, change: nil
  end

  @spec can_access_field?(field :: Field.t() | UpdateField.t(), user :: User.t() | nil) ::
          boolean()
  defp can_access_field?(field, user) do
    see_private = PenguinMemories.Auth.can_see_private(user)

    case {see_private, field} do
      {true, %{}} -> true
      {false, %{access: :private}} -> false
      {false, %{}} -> true
    end
  end

  @spec filter_accessible_fields(
          fields :: list(Field.t() | UpdateField.t()),
          user :: User.t() | nil
        ) :: list(Field.t() | UpdateField.t())
  defp filter_accessible_fields(fields, user) do
    Enum.filter(fields, fn field -> can_access_field?(field, user) end)
  end

  @spec get_fields(type :: object_type, user :: User.t() | nil) :: list(Field.t())
  def get_fields(type, user) do
    backend = Types.get_backend!(type)

    backend.get_fields()
    |> filter_accessible_fields(user)
  end

  @spec get_update_fields(type :: object_type, user :: User.t() | nil) :: list(UpdateField.t())
  def get_update_fields(type, user) do
    backend = Types.get_backend!(type)

    backend.get_update_fields()
    |> filter_accessible_fields(user)
  end
end
