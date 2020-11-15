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

    case {value1, value2} do
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

  @spec validate_list_ids(String.t()) :: {:ok, list(integer())} | {:error, String.t()}
  def validate_list_ids(nil), do: {:ok, []}
  def validate_list_ids(string) do
    {values, errors} = string
    |> String.split(",")
    |> Enum.map(fn str_id ->
      case Integer.parse(str_id) do
        {id, ""} -> {:ok, id}
        _ -> {:error, "Cannot parse #{str_id}"}
      end
    end)
    |> Enum.split_with(fn
        {:ok, _id} -> true
        {:error, _msg} -> false
    end)

    cond do
      length(errors) > 0 ->
        [{:error, error} | _] = errors
        {:error, error}
      true ->
        {:ok, Enum.map(values, fn {:ok, id} -> id end)}
    end
  end
end
