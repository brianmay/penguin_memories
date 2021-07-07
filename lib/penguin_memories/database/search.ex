defmodule PenguinMemories.Database.Search do
  @moduledoc """
  Provide text based filtering for objects.
  """
  import Ecto.Query

  alias PenguinMemories.Database
  alias PenguinMemories.Database.Fields
  alias PenguinMemories.Database.Types

  @type object_type :: Database.object_type()

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

  @spec filter_by_join_string(
          query :: Ecto.Query.t(),
          id :: atom(),
          op :: String.t(),
          string :: String.t()
        ) :: {:ok, Ecto.Query.t()}
  defp filter_by_join_string(%Ecto.Query{} = query, id, op, string) do
    case Integer.parse(string) do
      {value, ""} ->
        filter_by_join(query, id, op, value)

      _ ->
        {:error, "Cannot parse #{string} as integer"}
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
          string :: String.t()
        ) :: {:ok, Ecto.Query.t()}
  defp filter_by_integer_string(%Ecto.Query{} = query, id, op, string) do
    case Integer.parse(string) do
      {value, ""} ->
        filter_by_number(query, id, op, value)

      _ ->
        {:error, "Cannot parse #{string} as integer"}
    end
  end

  @spec filter_by_float_string(
          query :: Ecto.Query.t(),
          id :: atom(),
          op :: String.t(),
          string :: String.t()
        ) :: {:ok, Ecto.Query.t()}
  defp filter_by_float_string(%Ecto.Query{} = query, id, op, string) do
    case Integer.parse(string) do
      {value, ""} ->
        filter_by_number(query, id, op, value)

      _ ->
        {:error, "Cannot parse #{string} as integer"}
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

  @spec filter_by_field(
          query :: Ecto.Query.t(),
          field :: Fields.Field.t(),
          op :: String.t(),
          value :: String.t()
        ) :: {:ok, Ecto.Query.t()} | {:error, String.t()}
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp filter_by_field(%Ecto.Query{} = query, %Fields.Field{} = field, op, value) do
    case field.type do
      :datetime ->
        filter_by_date_string(query, field.id, op, value)

      {:datetime_with_offset, _} ->
        filter_by_date_string(query, field.id, op, value)

      :string ->
        filter_by_words(query, field.id, op, value)

      :integer ->
        filter_by_integer_string(query, field.id, op, value)

      :float ->
        filter_by_float_string(query, field.id, op, value)

      {:single, _} ->
        id = String.to_atom(Atom.to_string(field.id) <> "_id")
        filter_by_integer_string(query, id, op, value)

      {:multiple, _} ->
        query = join(query, :inner, [object: o], assoc(o, ^field.id))
        filter_by_join_string(query, :id, op, value)

      :persons ->
        query = join(query, :inner, [object: o], assoc(o, ^field.id))
        filter_by_join_string(query, :person_id, op, value)

      _ ->
        {:error, "Unknown field type #{inspect(field.type)}"}
    end
  end

  @spec filter_by_value(
          words :: list(String.t()),
          new_words :: list(String.t()),
          query :: Ecto.Query.t(),
          backend :: PenguinMemories.Database.Types.backend_type()
        ) :: {:ok, words :: list(String.t()), Ecto.Query.t()} | {:error, String.t()}
  def filter_by_value([], new_words, %Ecto.Query{} = query, _backend) do
    {:ok, new_words, query}
  end

  def filter_by_value([word | words], new_words, %Ecto.Query{} = query, backend) do
    fields = backend.get_fields()

    result =
      case partition_value(word) do
        {key, op, value} ->
          lc_key = String.downcase(key)

          field =
            fields
            |> Enum.filter(fn field ->
              Atom.to_string(field.id) == lc_key or String.downcase(field.name) == lc_key
            end)
            |> Enum.filter(fn field -> field.searchable == true end)
            |> List.first()

          if field == nil do
            {:error, "Field #{key} is not searchable"}
          else
            filter_by_field(query, field, op, value)
          end

        word ->
          {:ok, [word | new_words], query}
      end

    case result do
      {:ok, new_words, %Ecto.Query{} = query} ->
        filter_by_value(words, new_words, query, backend)

      {:ok, %Ecto.Query{} = query} ->
        filter_by_value(words, new_words, query, backend)

      {:error, _} = error ->
        error
    end
  end

  @spec partition_value(String.t()) :: {String.t(), String.t(), String.t()} | String.t()
  def partition_value(string) do
    case String.split(string, ~r/\b/, trim: true, parts: 3) do
      [a, op, b] -> {a, op, b}
      _ -> string
    end
  end

  @spec filter_by_id(query :: Ecto.Query.t(), id :: integer()) :: {:ok, Ecto.Query.t()}
  defp filter_by_id(%Ecto.Query{} = query, id) do
    query = where(query, [object: o], o.id == ^id)
    {:ok, query}
  end

  @spec filter_by_string(query :: Ecto.Query.t(), query_string :: String.t()) ::
          {:ok, Ecto.Query.t()} | {:error, String.t()}
  defp filter_by_string(%Ecto.Query{} = query, query_string) do
    backend = get_query_backend(query)

    result =
      String.split(query_string)
      |> filter_by_value([], query, backend)

    case result do
      {:ok, words, query} ->
        case filter_by_words(query, :name, "~", Enum.join(words, " ")) do
          {:ok, query} ->
            {:ok, query}

          {:error, _} = error ->
            error
        end

      {:error, _} = error ->
        error
    end
  end

  @spec filter_by_query(query :: Ecto.Query.t(), query_string :: String.t()) ::
          {:ok, Ecto.Query.t()} | {:error, String.t()}
  def filter_by_query(%Ecto.Query{} = query, nil) do
    {:ok, query}
  end

  def filter_by_query(%Ecto.Query{} = query, query_string) do
    case Integer.parse(query_string) do
      {id, ""} -> filter_by_id(query, id)
      _ -> filter_by_string(query, query_string)
    end
  end
end
