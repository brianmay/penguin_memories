defmodule PenguinMemories.Database.Impl.Backend.Private do
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

  @spec get_enabled_fields(enabled :: MapSet.t(), allowed_list :: list(atom())) :: list(atom())
  def get_enabled_fields(enabled, allowed_list) do
    allowed_list
    |> MapSet.new()
    |> MapSet.intersection(enabled)
    |> MapSet.to_list()
  end

  @spec selective_cast(
          data :: struct(),
          attrs :: map(),
          enabled :: MapSet.t(),
          allowed :: list(atom())
        ) :: Changeset.t()
  def selective_cast(%{} = data, %{} = attrs, enabled, allowed) do
    cast(data, attrs, get_enabled_fields(enabled, allowed))
  end

  # @spec selective_cast_assoc(
  #         changeset :: Changeset.t(),
  #         enabled :: MapSet.t(),
  #         allowed :: list(atom())
  #       ) :: Changeset.t()
  # def selective_cast_assoc(%Changeset{} = changeset, enabled, allowed) do
  #   fields = get_enabled_fields(enabled, allowed)

  #   Enum.reduce(fields, changeset, fn field, changeset ->
  #     cast_assoc(changeset, field)
  #   end)
  # end

  @spec selective_validate_required(
          changeset :: Changeset.t(),
          enabled :: MapSet.t(),
          allowed :: list(atom())
        ) :: Changeset.t()
  def selective_validate_required(%Changeset{} = changeset, enabled, allowed) do
    fields = get_enabled_fields(enabled, allowed)
    validate_required(changeset, fields)
  end

  # @spec validate_required_if_set(changeset :: Changeset.t(), fields :: list(atom())) :: Changeset.t()
  # def validate_required_if_set(changeset, fields) do
  #   Enum.reduce(fields, changeset, fn field_id, changeset ->
  #     case Changeset.fetch_change(changeset, field_id) do
  #       {:ok, _} -> validate_required(changeset, field_id)
  #       :error -> changeset
  #     end
  #   end)
  # end

  @spec put_all_assoc(changeset :: Changeset.t(), assoc :: map(), allowed :: list(atom())) ::
          Changeset.t()
  def put_all_assoc(changeset, assoc, allowed) do
    Enum.reduce(allowed, changeset, fn field_id, changeset ->
      case Map.fetch(assoc, field_id) do
        {:ok, value} -> Ecto.Changeset.put_assoc(changeset, field_id, value)
        :error -> changeset
      end
    end)
  end

  @spec selective_put_assoc(
          changeset :: Changeset.t(),
          assoc :: map(),
          enabled :: MapSet.t(),
          allowed :: list(atom())
        ) ::
          Changeset.t()
  def selective_put_assoc(changeset, assoc, enabled, allowed) do
    fields = get_enabled_fields(enabled, allowed)

    Enum.reduce(fields, changeset, fn field_id, changeset ->
      case Map.fetch(assoc, field_id) do
        {:ok, value} -> Ecto.Changeset.put_assoc(changeset, field_id, value)
        :error -> changeset
      end
    end)
  end
end
