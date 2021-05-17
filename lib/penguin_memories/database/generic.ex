defmodule PenguinMemories.Database.Generic do
  @moduledoc """
  Generic database functions
  """
  import Ecto.Query

  alias PenguinMemories.Database.API
  alias PenguinMemories.Repo

  @callback get_parent_fields() :: list(atom())
  @callback get_index_type() :: module() | nil

  @type object_type :: API.object_type()

  @behaviour API

  @impl API
  @spec get_parent_ids(integer, object_type) :: list(integer())
  def get_parent_ids(id, type) when is_integer(id) do
    fields = type.get_parent_fields()

    case fields do
      [] ->
        []

      fields ->
        query =
          from o in type,
            where: o.id == ^id,
            select: map(o, ^fields)

        o = Repo.one!(query)
        Enum.map(o, fn {_, v} -> v end)
    end
  end

  @impl API
  @spec get_child_ids(integer, object_type) :: list(integer())
  def get_child_ids(id, type) do
    fields = type.get_parent_fields()

    dynamic =
      Enum.reduce(fields, false, fn field_name, dynamic ->
        dynamic([o], field(o, ^field_name) == ^id or ^dynamic)
      end)

    query =
      from o in type,
        where: ^dynamic,
        select: o.id

    Repo.all(query)
  end

  @impl API
  @spec get_index(integer, object_type) :: MapSet.t()
  def get_index(id, type) do
    case type.get_index_type() do
      nil ->
        []

      index_type ->
        query =
          from oa in index_type,
            where: oa.descendant_id == ^id,
            select: {oa.ascendant_id, oa.position}

        Enum.reduce(Repo.all(query), MapSet.new(), fn result, mapset ->
          MapSet.put(mapset, result)
        end)
    end
  end

  @impl API
  @spec create_index(integer, {integer, integer}, object_type) :: :ok
  def create_index(id, index, type) do
    case type.get_index_type() do
      nil ->
        :ok

      index_type ->
        {referenced_id, position} = index

        Repo.insert!(
          struct(index_type,
            ascendant_id: referenced_id,
            descendant_id: id,
            position: position
          )
        )

        :ok
    end
  end

  @impl API
  @spec delete_index(integer, {integer, integer}, object_type) :: :ok
  def delete_index(id, index, type) do
    case type.get_index_type() do
      nil ->
        :ok

      index_type ->
        {referenced_id, _position} = index

        Repo.delete_all(
          from oa in index_type,
            where: oa.ascendant_id == ^referenced_id and oa.descendant_id == ^id
        )

        :ok
    end
  end
end
