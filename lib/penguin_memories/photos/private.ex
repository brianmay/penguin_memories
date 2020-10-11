defmodule PenguinMemories.Photos.Private do
  @moduledoc false
  alias Ecto.Changeset
  import Ecto.Changeset

  @spec validate_pair(Changeset.t(), atom(), atom()) :: Changeset.t()
  def validate_pair(%Changeset{} = changeset, key1, key2) do
    value1 = get_field(changeset, key1)
    value2 = get_field(changeset, key2)

    string1 = Atom.to_string(key1)
    string2 = Atom.to_string(key2)

    case {value1, value2}  do
      {nil, nil} ->
        changeset

      {_, nil} ->
        add_error(changeset, key2, "If #{string1} supplied then #{string2} must be supplied too")

      {nil, _} ->
        add_error(changeset, key1, "If #{string2} supplied then #{string1} must be supplied too")

      {_, _} ->
        changeset
    end
  end
end
