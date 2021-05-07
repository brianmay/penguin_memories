defmodule PenguinMemories.Actions do
  @moduledoc """
  Process pending photo actions.
  """
  import Ecto.Query

  alias PenguinMemories.Media
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo
  alias PenguinMemories.Storage

  @spec get_original_file(Photo.t()) :: File.t()
  defp get_original_file(%Photo{} = photo) do
    [original] =
      photo.files
      |> Enum.filter(fn file -> file.size_key == "orig" end)

    original
  end

  @spec process_photo(Photo.t()) :: :ok
  def process_photo(%Photo{action: "R"} = photo) do
    sizes = Storage.get_image_sizes()

    files =
      Enum.map(sizes, fn {size_key, %Media.SizeRequirement{} = sr} ->
        {:ok, original_media} =
          photo
          |> get_original_file()
          |> Storage.get_photo_file_media()

        temp_path = Temp.path!()
        {:ok, thumb} = Media.resize(original_media, temp_path, sr)
        {:ok, file} = Storage.build_file_from_media(photo, thumb, size_key)

        file
      end)

    photo
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:files, files)
    |> Repo.update!()
  end

  def process_photo(_) do
    :ok
  end

  @spec process_pending() :: :ok
  def process_pending do
    Repo.all(from p in Photo, where: not is_nil(p.action), preload: :files)
    |> Enum.each(fn photo -> process_photo(photo) end)
  end
end
