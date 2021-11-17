defmodule PenguinMemories.Database.Search do
  @moduledoc """
  Provide text based filtering for objects.
  """
  import Ecto.Query

  alias PenguinMemories.Database
  alias PenguinMemories.Database.Fields
  alias PenguinMemories.Database.Types
  alias PenguinMemories.Photos

  @type object_type :: Database.object_type()

  @spec get_query_type(query :: Ecto.Query.t()) :: object_type()
  defp get_query_type(%Ecto.Query{} = query) do
    {_, type} = query.from.source
    type
  end

  # @spec get_query_backend(query :: Ecto.Query.t()) ::
  #         PenguinMemories.Database.Types.backend_type()
  # defp get_query_backend(%Ecto.Query{} = query) do
  #   query
  #   |> get_query_type()
  #   |> Types.get_backend!()
  # end

  @spec date_to_utc(date :: Date.t()) :: DateTime.t()
  def date_to_utc(date) do
    date
    |> DateTime.new!(~T[00:00:00], "Australia/Melbourne")
    |> DateTime.shift_zone!("Etc/UTC")
  end

  @spec date_tomorrow_to_utc(date :: Date.t()) :: DateTime.t()
  def date_tomorrow_to_utc(date) do
    date
    |> Date.add(1)
    |> DateTime.new!(~T[00:00:00], "Australia/Melbourne")
    |> DateTime.shift_zone!("Etc/UTC")
  end

  @spec filter_by_date(
          query :: Ecto.Query.t(),
          id :: atom(),
          op :: String.t(),
          date :: Date.t()
        ) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp filter_by_date(%Ecto.Query{} = query, id, op, date) do
    case op do
      "=" ->
        start = date_to_utc(date)
        stop = date_tomorrow_to_utc(date)
        query = where(query, [object: o], field(o, ^id) >= ^start and field(o, ^id) < ^stop)
        {:ok, query}

      "<" ->
        date = date_to_utc(date)
        query = where(query, [object: o], field(o, ^id) < ^date)
        {:ok, query}

      "<=" ->
        date = date_tomorrow_to_utc(date)
        query = where(query, [object: o], field(o, ^id) < ^date)
        {:ok, query}

      ">" ->
        date = date_tomorrow_to_utc(date)
        query = where(query, [object: o], field(o, ^id) >= ^date)
        {:ok, query}

      ">=" ->
        date = date_to_utc(date)
        query = where(query, [object: o], field(o, ^id) >= ^date)
        {:ok, query}

      op ->
        {:error, "Invalid operation #{op}"}
    end
  end

  @spec filter_by_date_string(
          query :: Ecto.Query.t(),
          id :: atom(),
          op :: String.t(),
          value :: String.t()
        ) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  defp filter_by_date_string(%Ecto.Query{} = query, id, op, value) do
    case Date.from_iso8601(value) do
      {:ok, date} ->
        filter_by_date(query, id, op, date)

      {:error, _} ->
        {:error, "Invalid date #{value}"}
    end
  end

  @spec filter_by_join(
          query :: Ecto.Query.t(),
          id :: atom(),
          op :: String.t(),
          value :: integer() | float()
        ) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp filter_by_join(%Ecto.Query{} = query, id, op, value) do
    case op do
      "=" ->
        query = where(query, [o, ..., x], field(x, ^id) == ^value)
        {:ok, query}

      "<" ->
        query = where(query, [o, ..., x], field(x, ^id) < ^value)
        {:ok, query}

      "<=" ->
        query = where(query, [o, ..., x], field(x, ^id) <= ^value)
        {:ok, query}

      ">" ->
        query = where(query, [o, ..., x], field(x, ^id) > ^value)
        {:ok, query}

      ">=" ->
        query = where(query, [o, ..., x], field(x, ^id) >= ^value)
        {:ok, query}

      op ->
        {:error, "Invalid operation #{op}"}
    end
  end

  @spec check_type(Fields.Field.t(), value :: String.t() | integer() | float()) :: :ok | :error
  def check_type(field, value) do
    ok =
      case field.type do
        :integer -> is_integer(value)
        :float -> is_integer(value) or is_float(value)
        :string -> is_binary(value)
        _ -> false
      end

    if ok do
      :ok
    else
      :error
    end
  end

  @spec filter_by_join_string(
          query :: Ecto.Query.t(),
          id :: atom(),
          type :: object_type(),
          subfield :: String.t(),
          op :: String.t(),
          string :: String.t() | integer()
        ) :: {:ok, Ecto.Query.t()}
  defp filter_by_join_string(%Ecto.Query{} = query, id, type, subfield_name, op, string) do
    subfield_name = subfield_name || "id"

    case get_field(type, subfield_name) do
      {:ok, subfield} ->
        case check_type(subfield, string) do
          :ok ->
            query = join(query, :inner, [object: o], assoc(o, ^id))
            filter_by_join(query, subfield.id, op, string)

          :error ->
            {:error, "The value #{string} is invalid"}
        end

      :error ->
        {:error, "The field #{inspect(type)} #{subfield_name} is not searchable"}
    end
  end

  @spec filter_by_number(
          query :: Ecto.Query.t(),
          id :: atom(),
          op :: String.t(),
          value :: integer() | float()
        ) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp filter_by_number(%Ecto.Query{} = query, id, op, value) do
    case op do
      "=" ->
        query = where(query, [object: o], field(o, ^id) == ^value)
        {:ok, query}

      "<" ->
        query = where(query, [object: o], field(o, ^id) < ^value)
        {:ok, query}

      "<=" ->
        query = where(query, [object: o], field(o, ^id) <= ^value)
        {:ok, query}

      ">" ->
        query = where(query, [object: o], field(o, ^id) > ^value)
        {:ok, query}

      ">=" ->
        query = where(query, [object: o], field(o, ^id) >= ^value)
        {:ok, query}

      op ->
        {:error, "Invalid operation #{op}"}
    end
  end

  @spec filter_by_integer_string(
          query :: Ecto.Query.t(),
          id :: atom(),
          op :: String.t(),
          value :: String.t() | integer() | float()
        ) :: {:ok, Ecto.Query.t()}
  defp filter_by_integer_string(%Ecto.Query{} = query, id, op, value) do
    if is_integer(value) do
      filter_by_number(query, id, op, value)
    else
      {:error, "Cannot parse #{value} as integer"}
    end
  end

  @spec filter_by_float_string(
          query :: Ecto.Query.t(),
          id :: atom(),
          op :: String.t(),
          value :: String.t() | integer() | float()
        ) :: {:ok, Ecto.Query.t()}
  defp filter_by_float_string(%Ecto.Query{} = query, id, op, value) do
    if is_integer(value) or is_float(value) do
      filter_by_number(query, id, op, value)
    else
      {:error, "Cannot parse #{value} as integer"}
    end
  end

  @spec filter_by_words(
          query :: Ecto.Query.t(),
          id :: atom(),
          op :: String.t(),
          value :: String.t()
        ) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp filter_by_words(%Ecto.Query{} = query, id, op, value) do
    value = to_string(value)

    case {value, op} do
      {_, "="} ->
        query = where(query, [object: o], field(o, ^id) == ^value)
        {:ok, query}

      {_, "<"} ->
        query = where(query, [object: o], field(o, ^id) < ^value)
        {:ok, query}

      {_, "<="} ->
        query = where(query, [object: o], field(o, ^id) <= ^value)
        {:ok, query}

      {_, ">"} ->
        query = where(query, [object: o], field(o, ^id) > ^value)
        {:ok, query}

      {_, ">="} ->
        query = where(query, [object: o], field(o, ^id) >= ^value)
        {:ok, query}

      {value, "~"} when value != "" ->
        query =
          where(
            query,
            [object: o],
            fragment("to_tsvector(?) @@ plainto_tsquery(?)", field(o, ^id), ^value)
          )

        {:ok, query}

      {"", "~"} ->
        {:ok, query}

      {_, op} ->
        {:error, "Invalid operation #{op}"}
    end
  end

  @spec get_field(type :: object_type, field_name :: String.t()) ::
          {:ok, Fields.Field.t()} | :error
  def get_field(type, field_name) do
    backend = Types.get_backend!(type)
    fields = backend.get_fields()

    lc_key = String.downcase(field_name)

    field =
      fields
      |> Enum.filter(fn field ->
        (Atom.to_string(field.id) == lc_key or String.downcase(field.name) == lc_key) and
          field.searchable == true
      end)
      |> List.first()

    if field == nil do
      :error
    else
      {:ok, field}
    end
  end

  @spec filter_by_field(
          query :: Ecto.Query.t(),
          field :: Fields.Field.t(),
          subfield :: String.t(),
          op :: String.t(),
          value :: String.t() | integer() | float()
        ) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp filter_by_field(%Ecto.Query{} = query, %Fields.Field{} = field, subfield, op, value) do
    case {field.type, subfield} do
      {:datetime, nil} ->
        filter_by_date_string(query, field.id, op, value)

      {{:datetime_with_offset, _}, nil} ->
        filter_by_date_string(query, field.id, op, value)

      {:string, nil} ->
        filter_by_words(query, field.id, op, value)

      {:integer, nil} ->
        filter_by_integer_string(query, field.id, op, value)

      {:float, nil} ->
        filter_by_float_string(query, field.id, op, value)

      {{:single, type}, subfield} ->
        filter_by_join_string(query, field.id, type, subfield, op, value)

      {{:multiple, type}, subfield} ->
        filter_by_join_string(query, field.id, type, subfield, op, value)

      {:persons, subfield} ->
        filter_by_join_string(query, :persons, Photos.Person, subfield, op, value)

      _ ->
        {:error, "Unknown field type #{inspect(field.type)}"}
    end
  end

  @spec ops_get_field_name({any(), any(), any()}) :: String.t()
  def ops_get_field_name({key, _, _}) do
    case key do
      {field_name, _} -> to_string(field_name)
      {field_name} -> to_string(field_name)
    end
  end

  @spec ops_get_subfield_name({any(), any(), any()}) :: String.t() | nil
  def ops_get_subfield_name({key, _, _}) do
    case key do
      {_, subfield_name} -> to_string(subfield_name)
      {_} -> nil
    end
  end

  @spec ops_get_op({any(), any(), any()}) :: String.t()
  def ops_get_op({_, op, _}) do
    to_string(op)
  end

  @spec ops_get_value({any(), any(), any()}) :: String.t() | integer() | float()
  def ops_get_value({_, _, value}) do
    cond do
      is_integer(value) -> value
      is_float(value) -> value
      value -> to_string(value)
    end
  end

  @spec filter_by_ops(
          query :: Ecto.Query.t(),
          list :: list()
        ) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_ops(%Ecto.Query{} = query, []) do
    {:ok, query}
  end

  def filter_by_ops(%Ecto.Query{} = query, [head | tail]) do
    type = get_query_type(query)

    field_name = ops_get_field_name(head)
    subfield_name = ops_get_subfield_name(head)
    op = ops_get_op(head)
    value = ops_get_value(head)

    result =
      case get_field(type, field_name) do
        {:ok, field} ->
          filter_by_field(query, field, subfield_name, op, value)

        :error ->
          {:error, "Field #{inspect(type)} #{field_name} is not searchable."}
      end

    case result do
      {:ok, %Ecto.Query{} = query} ->
        filter_by_ops(query, tail)

      {:error, _} = error ->
        error
    end
  end

  @spec filter_by_id(query :: Ecto.Query.t(), id :: integer()) :: {:ok, Ecto.Query.t()}
  defp filter_by_id(%Ecto.Query{} = query, id) do
    query = where(query, [object: o], o.id == ^id)
    {:ok, query}
  end

  @spec filter_by_query(query :: Ecto.Query.t(), query_string :: String.t()) ::
          {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_query(%Ecto.Query{} = query, nil) do
    {:ok, query}
  end

  def filter_by_query(%Ecto.Query{} = query, query_string) do
    case parse(query_string) do
      {:ok, {:id, id}} ->
        filter_by_id(query, id)

      {:ok, {:words, words}} ->
        words = Enum.map_join(words, " ", &to_string(&1))
        filter_by_words(query, :name, "~", words)

      {:ok, {:ops, list}} ->
        filter_by_ops(query, list)

      {:error, error} ->
        {:error, error}
    end
  end

  @spec parse(String.t()) ::
          {:ok, {:id, integer()} | {:words, list(String.t())} | {:ops, list()}}
          | {:error, String.t()}
  def parse(str) do
    charlist = str |> to_charlist()

    with {:ok, tokens, _} <- :penguin_memories_lexer.string(charlist),
         {:ok, result} <- :penguin_memories_parser.parse(tokens) do
      {:ok, result}
    else
      {:error, {_, :penguin_memories_lexer, {a, b}}, _} ->
        {:error, "Lexer error #{to_string(a)} #{to_string(b)}."}

      {:error, {_, :penguin_memories_parser, [a, b]}} ->
        {:error, "Parse error #{to_string(a)} #{Enum.join(b)}."}
    end
  end
end
