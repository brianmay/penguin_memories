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

  @spec create_file(Photo.t(), Media.t(), Media.SizeRequirement.t(), String.t()) :: File.t() | nil
  defp create_file(
         %Photo{} = photo,
         %Media{} = original_media,
         %Media.SizeRequirement{} = sr,
         size_key
       ) do
    is_video? = Media.is_video(original_media)

    if String.starts_with?(sr.format, "video") and not is_video? do
      nil
    else
      temp_path = Temp.path!()
      {:ok, thumb} = Media.resize(original_media, temp_path, sr)
      {:ok, file} = Storage.build_file_from_media(photo, thumb, size_key)
      file
    end
  end

  @spec get_id(File.t(), list(File.t())) :: integer() | nil
  defp get_id(%File{} = file, files) do
    files
    |> Enum.filter(fn f -> f.size_key == file.size_key end)
    |> Enum.filter(fn f -> f.mime_type == file.mime_type end)
    |> Enum.map(fn f -> f.id end)
    |> List.first()
  end

  @spec set_file_id(File.t() | nil, list(File.t())) :: File.t() | nil
  defp set_file_id(nil, _), do: nil

  defp set_file_id(%File{} = file, files) do
    %File{file | id: get_id(file, files)}
  end

  @spec process_photo(Photo.t(), keyword()) :: Photo.t()
  def process_photo(photo, opts \\ [])

  def process_photo(%Photo{action: "R"} = photo, opts) do
    original_file = get_original_file(photo)
    {:ok, original_media} = Storage.get_photo_file_media(original_file)

    sizes = Storage.get_sizes()

    files =
      Enum.map(sizes, fn {size_key, requirement} ->
        Enum.map(requirement, fn %Media.SizeRequirement{} = sr ->
          create_file(photo, original_media, sr, size_key)
          |> set_file_id(photo.files)
        end)
      end)
      |> List.flatten()
      |> Enum.reject(fn file -> is_nil(file) end)

    files = [original_file | files]

    old_filenames =
      photo.files
      |> Enum.map(fn file -> {file.dir, file.name} end)
      |> MapSet.new()

    new_filenames =
      files
      |> Enum.map(fn file -> {file.dir, file.name} end)
      |> MapSet.new()

    MapSet.difference(old_filenames, new_filenames)
    |> Enum.each(fn {dir, name} ->
      path = Storage.build_path(dir, name)
      {:ok, media} = Media.get_media(path)

      if opts[:verbose] do
        IO.puts("Deleting #{path}")
      end

      :ok = Media.delete(media)
    end)

    photo =
      photo
      |> Ecto.Changeset.change(action: nil)
      |> Ecto.Changeset.put_assoc(:files, files)
      |> Repo.update!()

    if opts[:verbose] do
      IO.puts("Done #{Photo.to_string(photo)}")

      Enum.each(photo.files, fn file ->
        IO.puts("     #{File.to_string(file)}")
      end)
    end

    photo
  end

  def process_photo(_, _) do
    :ok
  end

  @spec internal_process_pending(list(Photo.t()), integer, keyword()) :: list(Photo.t())
  defp internal_process_pending(photos, start_id, opts) do
    photo =
      Repo.one(
        from p in Photo,
          where: not is_nil(p.action) and p.id >= ^start_id,
          preload: :files,
          limit: 1,
          order_by: :id
      )

    case photo do
      nil ->
        photos

      photo ->
        photos = [process_photo(photo, opts) | photos]
        internal_process_pending(photos, photo.id + 1, opts)
    end
  end

  @spec process_pending(keyword()) :: list(Photo.t())
  def process_pending(opts \\ []) do
    internal_process_pending([], 0, opts)
  end
end
