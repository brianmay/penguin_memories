defmodule PenguinMemories.Database.Impl.Index.Generic do
  @moduledoc """
  Functions used for indexing.
  """
  import Ecto.Query

  alias PenguinMemories.Database
  alias PenguinMemories.Database.Impl.Index.API
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Repo

  @callback get_parent_fields() :: list(atom())
  @callback get_index_type() :: module() | nil

  @type object_type :: Database.object_type()

  @behaviour API

  @impl API
  @spec get_parent_ids(id :: integer, type :: object_type) :: list(integer())
  def get_parent_ids(id, type) when is_integer(id) do
    backend = Types.get_backend!(type)
    fields = backend.get_parent_fields()

    case fields do
      [] ->
        []

      fields ->
        query =
          from o in type,
            where: o.id == ^id,
            select: map(o, ^fields)

        o = Repo.one!(query)

        o
        |> Enum.map(fn {_, v} -> v end)
        |> Enum.reject(fn v -> is_nil(v) end)
    end
  end

  @impl API
  @spec get_child_ids(id :: integer, type :: object_type) :: list(integer())
  def get_child_ids(id, type) do
    backend = Types.get_backend!(type)
    fields = backend.get_parent_fields()

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
  @spec get_index(id :: integer, type :: object_type) :: MapSet.t()
  def get_index(id, type) do
    backend = Types.get_backend!(type)

    case backend.get_index_type() do
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
  @spec create_index(id :: integer, index :: {integer, integer}, type :: object_type) :: :ok
  def create_index(id, index, type) do
    backend = Types.get_backend!(type)

    case backend.get_index_type() do
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
  @spec delete_index(id :: integer, index :: {integer, integer}, type :: object_type) :: :ok
  def delete_index(id, index, type) do
    backend = Types.get_backend!(type)

    case backend.get_index_type() do
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
