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
    original_file = get_original_file(photo)
    {:ok, original_media} = Storage.get_photo_file_media(original_file)

    image_sizes = Storage.get_image_sizes()

    video_sizes =
      case original_file.is_video do
        true -> Storage.get_video_sizes()
        false -> []
      end

    image_files =
      Enum.map(image_sizes, fn {size_key, %Media.SizeRequirement{} = sr} ->
        temp_path = Temp.path!()
        {:ok, thumb} = Media.resize(original_media, temp_path, sr)
        {:ok, file} = Storage.build_file_from_media(photo, thumb, size_key)

        file
      end)

    image_files = [original_file | image_files]

    video_files =
      Enum.map(video_sizes, fn {size_key, %Media.SizeRequirement{} = sr} ->
        temp_path = Temp.path!()
        {:ok, thumb} = Media.resize(original_media, temp_path, sr)
        {:ok, file} = Storage.build_file_from_media(photo, thumb, size_key)

        file
      end)

    photo
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:files, image_files)
    |> Ecto.Changeset.put_assoc(:videos, video_files)
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
