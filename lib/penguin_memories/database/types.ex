defmodule PenguinMemories.Database.Types do
  @types %{
    "album" => PenguinMemories.Photos.Album,
    "category" => PenguinMemories.Photos.Category,
    "person" => PenguinMemories.Photos.Person,
    "place" => PenguinMemories.Photos.Place,
    "photo" => PenguinMemories.Photos.Photo,
  }

  @names for {k, v} <- @types, into: %{}, do: {v, k}

  @spec get_type_for_name(name :: String.t()) :: {:ok, module()} | :error
  def get_type_for_name(name) do
    Map.fetch(@types, name)
  end

  @spec get_name_for_type(type :: module()) :: {:ok, String.t()} | :error
  def get_name_for_type(type) do
    Map.fetch(@names, type)
  end
end
