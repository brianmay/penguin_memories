defmodule PenguinMemories.Actions do
  @moduledoc """
  Process pending photo actions.
  """
  import Ecto.Query

  alias Ecto.Changeset
  import Ecto.Changeset

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

  @spec get_existing_entry(File.t(), list(File.t())) :: File.t() | nil
  defp get_existing_entry(%File{} = file, files) do
    files
    |> Enum.filter(fn f -> f.size_key == file.size_key end)
    |> Enum.filter(fn f -> f.mime_type == file.mime_type end)
    |> List.first()
  end

  @spec update_entry(File.t() | nil, list(File.t())) :: Changeset.t()
  defp update_entry(nil, _), do: nil

  defp update_entry(%File{} = file, files) do
    changes = %{
      dir: file.dir,
      height: file.height,
      is_video: file.is_video,
      mime_type: file.mime_type,
      filename: file.filename,
      num_bytes: file.num_bytes,
      sha256_hash: file.sha256_hash,
      size_key: file.size_key,
      width: file.width,
      photo_id: file.photo_id
    }

    case get_existing_entry(file, files) do
      nil ->
        change(%File{}, changes)

      existing ->
        change(existing, changes)
    end
  end

  @spec regenerate_photo(Photo.t(), keyword()) :: Photo.t()
  def regenerate_photo(%Photo{action: "R"} = photo, opts) do
    original_file = get_original_file(photo)
    {:ok, original_media} = Storage.get_photo_file_media(original_file)

    sizes = Storage.get_sizes()

    files =
      Enum.map(sizes, fn {size_key, requirement} ->
        Enum.map(requirement, fn %Media.SizeRequirement{} = sr ->
          create_file(photo, original_media, sr, size_key)
          |> update_entry(photo.files)
        end)
      end)
      |> List.flatten()
      |> Enum.reject(fn file -> is_nil(file) end)

    original_file = update_entry(original_file, photo.files)
    files = [original_file | files]

    old_filenames =
      photo.files
      |> Enum.map(fn file -> {file.dir, file.filename} end)
      |> Enum.map(fn {dir, filename} -> Storage.build_path(dir, filename) end)
      |> MapSet.new()

    new_filenames =
      files
      |> Enum.map(fn file -> {fetch_field!(file, :dir), fetch_field!(file, :filename)} end)
      |> Enum.map(fn {dir, filename} -> Storage.build_path(dir, filename) end)
      |> MapSet.new()

    MapSet.difference(old_filenames, new_filenames)
    |> Enum.each(fn path ->
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
      IO.puts("Regenerated #{Photo.to_string(photo)}")

      Enum.each(photo.files, fn file ->
        IO.puts("--> #{File.to_string(file)}")
      end)
    end

    photo
  end

  @spec rotate_photo(Photo.t(), String.t(), keyword()) :: Photo.t()
  def rotate_photo(%Photo{} = photo, rotate_amount, opts) do
    {:ok, temp_path} = Temp.path()
    original_file = get_original_file(photo)
    path = Storage.get_photo_file_path(original_file)
    {:ok, original_media} = Storage.get_photo_file_media(original_file)
    {:ok, media} = Media.rotate(original_media, temp_path, rotate_amount)
    {:ok, media} = Media.copy(media, path)
    size = Media.get_size(media)

    files =
      Enum.map(photo.files, fn
        %File{size_key: "orig"} ->
          Ecto.Changeset.change(original_file, width: size.width, height: size.height)

        %File{} = file ->
          file
      end)

    photo =
      photo
      |> Ecto.Changeset.change(action: "R")
      |> Ecto.Changeset.put_assoc(:files, files)
      |> Repo.update!()

    if opts[:verbose] do
      IO.puts("Rotated #{Photo.to_string(photo)}")
    end

    photo
  end

  @spec process_photo(Photo.t(), keyword()) :: Photo.t()
  def process_photo(photo, opts \\ [])

  def process_photo(%Photo{action: "R"} = photo, opts) do
    regenerate_photo(photo, opts)
  end

  def process_photo(%Photo{action: rotate_amount} = photo, opts)
      when rotate_amount in ["auto", "90", "180", "270"] do
    rotate_photo(photo, rotate_amount, opts)
    |> regenerate_photo(opts)
  end

  def process_photo(%Photo{} = photo, _) do
    photo
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
