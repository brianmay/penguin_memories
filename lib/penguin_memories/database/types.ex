defmodule PenguinMemories.Database.Types do
  @moduledoc """
  Objects types used for Photos
  """
  @type object_type :: PenguinMemories.Database.object_type()

  @types %{
    "album" => PenguinMemories.Photos.Album,
    "category" => PenguinMemories.Photos.Category,
    "person" => PenguinMemories.Photos.Person,
    "place" => PenguinMemories.Photos.Place,
    "photo" => PenguinMemories.Photos.Photo
  }

  @type backend_type ::
          PenguinMemories.Database.Impl.Backend.Album
          | PenguinMemories.Database.Impl.Backend.Category
          | PenguinMemories.Database.Impl.Backend.Person
          | PenguinMemories.Database.Impl.Backend.Place
          | PenguinMemories.Database.Impl.Backend.Photo

  @query_backends %{
    PenguinMemories.Photos.Album => PenguinMemories.Database.Impl.Backend.Album,
    PenguinMemories.Photos.Category => PenguinMemories.Database.Impl.Backend.Category,
    PenguinMemories.Photos.Person => PenguinMemories.Database.Impl.Backend.Person,
    PenguinMemories.Photos.Place => PenguinMemories.Database.Impl.Backend.Place,
    PenguinMemories.Photos.Photo => PenguinMemories.Database.Impl.Backend.Photo
  }

  @names for {k, v} <- @types, into: %{}, do: {v, k}

  @spec get_type_for_name(name :: String.t()) :: {:ok, object_type()} | :error
  def get_type_for_name(name) do
    Map.fetch(@types, name)
  end

  @spec get_name!(type :: object_type()) :: String.t()
  def get_name!(type) do
    Map.fetch!(@names, type)
  end

  @spec get_backend!(type :: object_type()) :: backend_type()
  def get_backend!(type) do
    Map.fetch!(@query_backends, type)
  end
end
