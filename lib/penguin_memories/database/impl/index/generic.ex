defmodule PenguinMemories.Database.Impl.Index.Generic do
  @moduledoc """
  Functions used for indexing.
  """
  import Ecto.Query

  alias PenguinMemories.Database
  alias PenguinMemories.Database.Impl.Index.API
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Repo

  # @callback get_parent_id_fields() :: list(atom())
  # @callback get_index_type() :: module() | nil

  @type object_type :: Database.object_type()

  @behaviour API

  @impl API
  @spec get_parent_ids(id :: integer, type :: object_type) :: list(integer())
  def get_parent_ids(id, type) when is_integer(id) do
    backend = Types.get_backend!(type)
    fields = backend.get_parent_id_fields()

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
        |> Enum.reject(&is_nil/1)
    end
  end

  @impl API
  @spec get_child_ids(id :: integer, type :: object_type) :: list(integer())
  def get_child_ids(id, type) do
    backend = Types.get_backend!(type)
    fields = backend.get_parent_id_fields()

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
        MapSet.new()

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
  @spec bulk_update_index(
          id :: integer,
          to_delete :: list(integer()),
          to_upsert :: list({integer(), integer()}),
          type :: object_type
        ) :: :ok
  def bulk_update_index(id, to_delete, to_upsert, type) do
    backend = Types.get_backend!(type)

    case backend.get_index_type() do
      nil ->
        :ok

      index_type ->
        unless Enum.empty?(to_delete) do
          from(oa in index_type,
            where: oa.descendant_id == ^id and oa.ascendant_id in ^to_delete
          )
          |> Repo.delete_all()
        end

        unless Enum.empty?(to_upsert) do
          now = DateTime.utc_now()

          rows =
            Enum.map(to_upsert, fn {ascendant_id, position} ->
              %{
                ascendant_id: ascendant_id,
                descendant_id: id,
                position: position,
                inserted_at: now,
                updated_at: now
              }
            end)

          Repo.insert_all(
            index_type,
            rows,
            on_conflict: {:replace, [:position, :updated_at]},
            conflict_target: [:ascendant_id, :descendant_id]
          )
        end

        :ok
    end
  end

  @impl API
  @spec set_done(integer, object_type) :: :ok
  def set_done(id, type) do
    {1, _} =
      from(o in type, where: o.id == ^id)
      |> Repo.update_all(set: [reindex: false])

    :ok
  end
end
