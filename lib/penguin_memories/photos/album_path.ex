defmodule PenguinMemories.Photos.AlbumPath do
  @moduledoc """
  AlbumPath represents a complete hierarchical path from a root album down to a descendant album.

  This enables multiple breadcrumb trails for albums that appear in multiple parent hierarchies.
  For example, the same album might appear as:
  - "Life Events → Memorial Services → Uncle Peter's Memorial"  
  - "Travel → Great Ocean Road → Uncle Peter's Memorial"

  Each path is stored as a complete sequence with context information for display.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PenguinMemories.Photos.Album

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          descendant_id: integer(),
          descendant: Album.t() | Ecto.Association.NotLoaded.t(),
          path_ids: [integer()],
          path_contexts: map(),
          path_length: integer(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "pm_album_path" do
    belongs_to :descendant, Album

    field :path_ids, {:array, :integer}
    field :path_contexts, :map, default: %{}
    field :path_length, :integer

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = album_path, attrs) do
    album_path
    |> cast(attrs, [:descendant_id, :path_ids, :path_contexts])
    |> validate_required([:descendant_id, :path_ids])
    |> validate_path_ids()
    |> put_path_length()
    |> foreign_key_constraint(:descendant_id)
    |> unique_constraint([:descendant_id, :path_ids])
  end

  @spec validate_path_ids(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp validate_path_ids(changeset) do
    case get_field(changeset, :path_ids) do
      nil ->
        changeset

      [] ->
        add_error(changeset, :path_ids, "cannot be empty")

      path_ids when is_list(path_ids) ->
        descendant_id = get_field(changeset, :descendant_id)

        cond do
          not Enum.all?(path_ids, &is_integer/1) ->
            add_error(changeset, :path_ids, "must contain only integers")

          descendant_id && List.last(path_ids) != descendant_id ->
            add_error(changeset, :path_ids, "must end with descendant_id")

          length(path_ids) != length(Enum.uniq(path_ids)) ->
            add_error(changeset, :path_ids, "cannot contain duplicate album IDs (circular path)")

          true ->
            changeset
        end

      _ ->
        add_error(changeset, :path_ids, "must be a list of integers")
    end
  end

  @spec put_path_length(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp put_path_length(changeset) do
    case get_field(changeset, :path_ids) do
      nil -> changeset
      path_ids when is_list(path_ids) -> put_change(changeset, :path_length, length(path_ids))
    end
  end

  @doc """
  Creates a new AlbumPath changeset for the given descendant and path.

  ## Examples

      iex> new_path(123, [1, 5, 123], %{"1" => "Life Events", "5" => "Memorial Services"})
      %Ecto.Changeset{valid?: true}
  """
  @spec new_path(integer(), [integer()], map()) :: Ecto.Changeset.t()
  def new_path(descendant_id, path_ids, path_contexts \\ %{}) do
    %__MODULE__{}
    |> changeset(%{
      descendant_id: descendant_id,
      path_ids: path_ids,
      path_contexts: path_contexts
    })
  end

  @doc """
  Returns the root album ID for this path (first element in path_ids).
  """
  @spec get_root_id(t()) :: integer() | nil
  def get_root_id(%__MODULE__{path_ids: []}), do: nil
  def get_root_id(%__MODULE__{path_ids: [root_id | _]}), do: root_id

  @doc """
  Returns the immediate parent album ID for this path (second to last element).
  """
  @spec get_parent_id(t()) :: integer() | nil
  def get_parent_id(%__MODULE__{path_ids: path_ids}) when length(path_ids) < 2, do: nil

  def get_parent_id(%__MODULE__{path_ids: path_ids}) do
    path_ids
    |> Enum.reverse()
    |> Enum.at(1)
  end

  @doc """
  Returns true if this path represents a root album (length 1).
  """
  @spec is_root_path?(t()) :: boolean()
  def is_root_path?(%__MODULE__{path_length: 1}), do: true
  def is_root_path?(_), do: false
end
