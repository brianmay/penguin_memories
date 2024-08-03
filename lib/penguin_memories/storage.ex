defmodule PenguinMemories.Storage do
  @moduledoc """
  Helper functions for storage of media objects on filesystem.
  """
  import File
  alias PenguinMemories.Database.Conflicts
  alias PenguinMemories.Media
  alias PenguinMemories.Media.SizeRequirement
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo

  @spec get_image_dir() :: String.t()
  def get_image_dir do
    Application.get_env(:penguin_memories, :image_dir)
  end

  @spec get_sizes() :: %{required(String.t()) => list(SizeRequirement.t())}
  def get_sizes do
    sizes = Application.get_env(:penguin_memories, :sizes)
    formats = Application.get_env(:penguin_memories, :formats)

    Enum.reduce(sizes, %{}, fn {key, size}, result ->
      result_for_size =
        Enum.reduce(formats, [], fn format, result_for_size ->
          sr = %SizeRequirement{
            max_width: size.max_width,
            max_height: size.max_height,
            format: format
          }

          [sr | result_for_size]
        end)

      Map.put(result, key, result_for_size)
    end)
    |> Enum.into(%{})
  end

  @spec build_photo_dir(Date.t()) :: String.t()
  def build_photo_dir(date) do
    Timex.format!(date, "{YYYY}/{0M}/{0D}")
  end

  @spec build_file_dir(String.t(), String.t(), boolean()) :: String.t()
  def build_file_dir(photo_dir, size_key, _is_video) do
    cond do
      size_key == "orig" -> ["orig", photo_dir]
      size_key == "raw" -> ["raw", photo_dir]
      Map.has_key?(get_sizes(), size_key) -> ["scaled", size_key, photo_dir]
    end
    |> Path.join()
  end

  @spec build_directory(String.t()) :: String.t()
  def build_directory(new_dir) do
    Path.join([get_image_dir(), new_dir])
  end

  @spec build_path(String.t(), String.t()) :: String.t()
  def build_path(new_dir, new_name) do
    Path.join([get_image_dir(), new_dir, new_name])
  end

  @spec get_photo_file_path(File.t()) :: String.t()
  def get_photo_file_path(%File{} = file) do
    build_path(file.dir, file.filename)
  end

  @spec get_photo_file_media(File.t()) :: {:ok, Media.t()} | {:error, String.t()}
  def get_photo_file_media(%File{} = file) do
    path = get_photo_file_path(file)
    Media.get_media(path, file.mime_type)
  end

  @spec add_extension(String.t(), String.t()) :: String.t()
  defp add_extension(path, extension) do
    "#{path}.#{extension}"
  end

  @spec build_new_filename(Photo.t(), Media.t()) :: String.t()
  defp build_new_filename(%Photo{} = photo, %Media{} = media) do
    extension = Media.get_extension(media)

    photo.id
    |> Integer.to_string()
    |> String.pad_leading(8, "0")
    |> add_extension(extension)
  end

  @spec check_conflicts(boolean, String.t(), String.t()) :: :ok | {:error, String.t()}
  defp check_conflicts(false, _, _), do: :ok

  defp check_conflicts(true, file_dir, filename) do
    path = build_path(file_dir, filename)

    with [] <- Conflicts.get_file_dir_conflicts(file_dir, filename),
         {:error, _} <- stat(path) do
      :ok
    else
      [_conflicts] -> {:error, "Path #{path} already exists in database"}
      {:ok, _} -> {:error, "Path #{path} already exists on filesystem"}
    end
  end

  @spec build_file_from_media(Photo.t(), Media.t(), String.t(), keyword()) ::
          {:ok, File.t()} | {:error, String.t()}
  def build_file_from_media(%Photo{} = photo, %Media{} = media, size_key, opts \\ []) do
    filename = build_new_filename(photo, media)
    size = Media.get_size(media)
    sha256_hash = Media.get_sha256_hash(media)
    num_bytes = Media.get_num_bytes(media)
    format = Media.get_format(media)
    is_video = Media.is_video(media)

    file_dir = build_file_dir(photo.dir, size_key, is_video)
    dest_path = build_path(file_dir, filename)

    check_conflicts = Keyword.get(opts, :check_conflicts, false)

    with :ok <- check_conflicts(check_conflicts, file_dir, filename),
         {:ok, _} <- Media.copy(media, dest_path) do
      file = %File{
        size_key: size_key,
        width: size.width,
        height: size.height,
        dir: file_dir,
        filename: filename,
        is_video: is_video,
        mime_type: format,
        sha256_hash: sha256_hash,
        num_bytes: num_bytes,
        photo_id: photo.id
      }

      {:ok, file}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end
end
