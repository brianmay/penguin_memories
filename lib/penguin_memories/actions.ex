defmodule PenguinMemories.Actions do
  @moduledoc """
  Process pending photo actions.
  """
  import Ecto.Query

  alias Ecto.Changeset
  import Ecto.Changeset

  alias Logger
  require Logger
  alias PenguinMemories.Media
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo
  alias PenguinMemories.Repo
  alias PenguinMemories.Storage

  @spec get_original_file(Photo.t()) :: File.t() | nil
  defp get_original_file(%Photo{} = photo) do
    photo.files
    |> Enum.find(fn file -> file.size_key == "orig" end)
  end

  @spec get_raw_file(Photo.t()) :: File.t() | nil
  defp get_raw_file(%Photo{} = photo) do
    photo.files
    |> Enum.find(fn file -> file.size_key == "raw" end)
  end

  @spec create_file(Photo.t(), Media.t(), Media.SizeRequirement.t(), String.t()) :: File.t() | nil
  defp create_file(
         %Photo{} = photo,
         %Media{} = original_media,
         %Media.SizeRequirement{} = sr,
         size_key
       ) do
    if not Media.is_video(original_media) and String.starts_with?(sr.format, "video") do
      nil
    else
      temp_path = Temp.path!()

      try do
        create_file_inner(photo, original_media, sr, size_key, temp_path)
      after
        Elixir.File.rm(temp_path)
      end
    end
  end

  @spec create_file_inner(Photo.t(), Media.t(), Media.SizeRequirement.t(), String.t(), String.t()) ::
          File.t() | nil
  defp create_file_inner(photo, original_media, sr, size_key, temp_path) do
    case Media.resize(original_media, temp_path, sr) do
      {:ok, thumb} ->
        create_file_from_thumb(photo, thumb, size_key)

      {:error, reason} ->
        Logger.error("Failed to create #{size_key} for #{Photo.to_string(photo)}: #{reason}")
        nil
    end
  end

  @spec create_file_from_thumb(Photo.t(), Media.t(), String.t()) :: File.t() | nil
  defp create_file_from_thumb(photo, thumb, size_key) do
    case Storage.build_file_metadata(thumb, photo, size_key) do
      {:ok, file, dest_path} ->
        case Storage.copy_file(thumb, dest_path) do
          :ok ->
            file

          {:error, reason} ->
            Logger.error("Failed to copy #{size_key}: #{reason}")
            nil
        end

      {:error, reason} ->
        Logger.error("Failed to build metadata for #{size_key}: #{reason}")
        nil
    end
  end

  @spec get_existing_entry(File.t(), list(File.t())) :: File.t() | nil
  defp get_existing_entry(%File{} = file, files) do
    files
    |> Enum.filter(fn f -> f.size_key == file.size_key and f.mime_type == file.mime_type end)
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

  @spec regenerate_photo(Photo.t()) :: Photo.t()
  def regenerate_photo(%Photo{} = photo) do
    Logger.info("Regnerating #{Photo.to_string(photo)}")

    original_file = get_original_file(photo)
    raw_file = get_raw_file(photo)
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

    files =
      if original_file != nil do
        original_file = update_entry(original_file, photo.files)
        [original_file | files]
      else
        files
      end

    files =
      if raw_file != nil do
        raw_file = update_entry(raw_file, photo.files)
        [raw_file | files]
      else
        files
      end

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
      case Media.get_media(path) do
        {:ok, media} ->
          Logger.info("Deleting #{path}")
          :ok = Media.delete(media)

        {:error, _reason} ->
          Logger.error("File not found, skipping delete: #{path}")
      end
    end)

    photo =
      photo
      |> Ecto.Changeset.change(action: nil)
      |> Ecto.Changeset.put_assoc(:files, files)
      |> Repo.update!()

    Logger.info("Regenerated #{Photo.to_string(photo)}")

    Enum.each(photo.files, fn file ->
      Logger.info("--> #{File.to_string(file)}")
    end)

    photo
  end

  @spec delete_photo(Photo.t()) :: Photo.t()
  def delete_photo(%Photo{} = photo) do
    old_filenames =
      photo.files
      |> Enum.map(fn file -> {file.dir, file.filename} end)
      |> Enum.map(fn {dir, filename} -> Storage.build_path(dir, filename) end)
      |> MapSet.new()

    old_filenames
    |> Enum.each(fn path ->
      case Media.get_media(path) do
        {:ok, media} ->
          Logger.info("Deleting #{path}")
          :ok = Media.delete(media)

        {:error, _reason} ->
          Logger.error("File not found, skipping delete: #{path}")
      end
    end)

    Repo.delete!(photo)

    Logger.info("Deleted #{Photo.to_string(photo)}")

    photo
  end

  @spec rotate_photo(Photo.t(), String.t()) :: Photo.t()
  def rotate_photo(%Photo{} = photo, rotate_amount) do
    {:ok, temp_path} = Temp.path()

    try do
      original_file = get_original_file(photo)
      path = Storage.get_photo_file_path(original_file)
      {:ok, original_media} = Storage.get_photo_file_media(original_file)

      if Media.is_video(original_media) do
        Logger.debug("Skipping rotation for video #{Photo.to_string(photo)}")

        photo
        |> Ecto.Changeset.change(action: "R")
        |> Repo.update!()
      else
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

        Logger.info("Rotated #{Photo.to_string(photo)}")

        photo
      end
    after
      Elixir.File.rm(temp_path)
    end
  end

  @spec process_photo(Photo.t(), keyword()) :: Photo.t()
  def process_photo(photo, _opts \\ [])

  def process_photo(%Photo{action: "D"} = photo, _opts) do
    delete_photo(photo)
  end

  def process_photo(%Photo{action: "R"} = photo, _opts) do
    regenerate_photo(photo)
  end

  def process_photo(%Photo{action: rotate_amount} = photo, _opts)
      when rotate_amount in ["auto", "90", "180", "270"] do
    rotate_photo(photo, rotate_amount)
    |> regenerate_photo()
  end

  def process_photo(%Photo{} = photo, _opts) do
    photo
  end

  @spec internal_process_pending(list(Photo.t()), integer) :: list(Photo.t())
  defp internal_process_pending(photos, start_id) do
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
        photos = [process_photo(photo) | photos]
        internal_process_pending(photos, photo.id + 1)
    end
  end

  @spec process_pending() :: list(Photo.t())
  def process_pending do
    Logger.info("Starting to process pending photos")
    photos = internal_process_pending([], 0)
    Logger.info("Finished processing #{length(photos)} pending photos")
    photos
  end
end
