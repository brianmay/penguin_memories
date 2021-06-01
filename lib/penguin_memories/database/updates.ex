defmodule PenguinMemories.Database.Updates do
  @moduledoc """
  Generic database functions
  """
  import Ecto.Query

  alias PenguinMemories.Database
  alias PenguinMemories.Database.Index
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Repo

  @type object_type :: Database.object_type()
  @type change_type :: :set | {:assoc, :set | :add | :delete} | nil

  defmodule UpdateChange do
    @moduledoc """
    A specific change to be applied in bulk.
    """
    @type change_type :: Database.Updates.change_type()
    @type field_type :: Database.Fields.field_type()

    @type t :: %__MODULE__{
            field_id: atom(),
            change: change_type,
            type: field_type(),
            value: any()
          }
    @enforce_keys [:field_id, :change, :type, :value]
    defstruct field_id: nil, change: nil, type: nil, value: nil
  end

  @spec get_object_backend(object :: struct()) ::
          PenguinMemories.Database.Types.backend_type()
  defp get_object_backend(%{__struct__: type}) do
    Types.get_backend!(type)
  end

  @spec get_query_type(query :: Ecto.Query.t()) :: object_type()
  defp get_query_type(%Ecto.Query{} = query) do
    {_, type} = query.from.source
    type
  end

  @spec get_query_backend(query :: Ecto.Query.t()) ::
          PenguinMemories.Database.Types.backend_type()
  defp get_query_backend(%Ecto.Query{} = query) do
    query
    |> get_query_type()
    |> Types.get_backend!()
  end

  # @spec apply_field_update(changeset :: Ecto.Changeset.t(), update :: UpdateChange.t()) ::
  #         Ecto.Changeset.t()
  # def apply_field_update(
  #       %Ecto.Changeset{} = changeset,
  #       %UpdateChange{change: :set, type: {:single, _}} = update
  #     ) do
  #   Ecto.Changeset.put_assoc(changeset, update.id, update.value)
  # end

  # def apply_field_update(
  #       %Ecto.Changeset{} = changeset,
  #       %UpdateChange{change: :set, type: {:multiple, _}} = update
  #     ) do
  #   Ecto.Changeset.put_assoc(changeset, update.id, update.value)
  # end

  # def apply_field_update(%Ecto.Changeset{} = changeset, %UpdateChange{change: :set} = update) do
  #   Ecto.Changeset.put_change(changeset, update.id, update.value)
  # end

  @spec get_current_value(object :: struct(), changes :: struct(), id :: atom(), default :: any()) ::
          any()
  defp get_current_value(object, %{} = changes, id, default) do
    case Map.fetch(changes, id) do
      {:ok, value} ->
        value

      :error ->
        case Map.fetch(object, id) do
          {:ok, %Ecto.Association.NotLoaded{}} -> default
          {:ok, value} -> value
          :error -> default
        end
    end
  end

  @spec get_new_value(any(), default :: any()) :: any()
  defp get_new_value(nil, default), do: default
  defp get_new_value(value, _), do: value

  @spec apply_update_to_object(
          updates :: list(UpdateChange.t()),
          object :: struct(),
          changes :: map(),
          assoc :: map
        ) :: {:ok, map(), map()}
  defp apply_update_to_object([], _object, changes, assoc), do: {:ok, changes, assoc}

  defp apply_update_to_object([%UpdateChange{} = head | tail], object, changes, assoc) do
    {changes, assoc} =
      case head do
        %UpdateChange{type: {:single, _}, change: :set} ->
          assoc = Map.put(assoc, head.field_id, head.value)
          {changes, assoc}

        %UpdateChange{type: {:multiple, _}, change: :set} ->
          assoc = Map.put(assoc, head.field_id, head.value)
          {changes, assoc}

        %UpdateChange{type: {:multiple, _}, change: :add} ->
          head_value = get_new_value(head.value, [])

          value =
            object
            |> get_current_value(assoc, head.field_id, [])
            |> Enum.reject(fn v -> Enum.any?(head_value, fn hv -> v.id == hv.id end) end)

          assoc = Map.put(assoc, head.field_id, head_value ++ value)
          {changes, assoc}

        %UpdateChange{type: {:multiple, _}, change: :delete} ->
          head_value = get_new_value(head.value, [])

          value =
            object
            |> get_current_value(assoc, head.field_id, [])
            |> Enum.reject(fn v -> Enum.any?(head_value, fn hv -> v.id == hv.id end) end)

          assoc = Map.put(assoc, head.field_id, value)
          {changes, assoc}

        %UpdateChange{type: _, change: :set} ->
          changes = Map.put(changes, head.field_id, head.value)
          {changes, assoc}
      end

    apply_update_to_object(tail, object, changes, assoc)
  end

  @spec get_update_changeset(object :: struct(), updates :: list(UpdateChange.t())) ::
          Ecto.Changeset.t()
  def get_update_changeset(object, updates) do
    backend = get_object_backend(object)

    enabled =
      Enum.reduce(updates, MapSet.new(), fn %UpdateChange{field_id: id}, enabled ->
        MapSet.put(enabled, id)
      end)

    {:ok, changes, assoc} = apply_update_to_object(updates, object, %{}, %{})
    changeset = backend.update_changeset(object, changes, assoc, enabled)

    %{changeset | action: :update}
  end

  @spec apply_updates_to_object(updates :: list(UpdateChange.t()), object :: struct()) ::
          {:ok, Ecto.Changeset.t(), struct()} | {:error, String.t()}
  defp apply_updates_to_object(updates, object) do
    changeset = get_update_changeset(object, updates)

    case Repo.update(changeset) do
      {:ok, new_obj} -> {:ok, changeset, new_obj}
      {:error, _} -> {:error, "Update of object #{object.id} failed"}
    end
  end

  @spec fix_index(
          result :: {:ok, Ecto.Changeset.t(), struct()} | {:error, String.t()},
          cache :: Index.cache_type()
        ) :: {:ok, Index.cache_type()} | {:error, String.t()}
  defp fix_index({:error, _} = rc, _cache), do: rc

  defp fix_index({:ok, %Ecto.Changeset{} = changeset, _new_obj}, cache) do
    Query.fix_index(changeset, cache)
  end

  @spec rollback_if_error(result :: {:ok, Index.cache_type()} | {:error, String.t()}) ::
          Index.cache_type()
  defp rollback_if_error({:ok, cache}), do: cache
  defp rollback_if_error({:error, reason}), do: Repo.rollback(reason)

  @spec decode_result({:ok, :ok} | {:error, String.t()}) :: :ok | {:error, String.t()}
  defp decode_result({:ok, :ok}), do: :ok
  defp decode_result({:error, _rc} = result), do: result

  @spec apply_updates(updates :: list(UpdateChange.t()), query :: Ecto.Query.t()) ::
          :ok | {:error, String.t()}
  def apply_updates(updates, %Ecto.Query{} = query) do
    backend = get_query_backend(query)

    Repo.transaction(fn ->
      query
      |> select_merge([object: o], %{o: o})
      |> Repo.stream()
      |> Stream.scan(%{}, fn result, cache ->
        [obj] = backend.preload_details_from_results([result.o])

        apply_updates_to_object(updates, obj)
        |> fix_index(cache)
        |> rollback_if_error()
      end)
      |> Stream.run()
    end)
    |> decode_result()
  end
end
