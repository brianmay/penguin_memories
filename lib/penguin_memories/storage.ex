defmodule PenguinMemories.Storage do
  @moduledoc """
  Helper functions for storage of media objects on filesystem.
  """
  import File
  alias PenguinMemories.Media
  alias PenguinMemories.Media.SizeRequirement
  alias PenguinMemories.Photos.File
  alias PenguinMemories.Photos.Photo

  @spec get_image_dir() :: String.t()
  def get_image_dir do
    Application.get_env(:penguin_memories, :image_dir)
  end

  @spec get_image_sizes() :: %{required(String.t()) => SizeRequirement.t()}
  def get_image_sizes do
    Application.get_env(:penguin_memories, :image_sizes)
    |> Enum.map(fn {key, %{} = value} -> {key, struct(SizeRequirement, value)} end)
    |> Enum.into(%{})
  end

  @spec get_video_sizes() :: %{required(String.t()) => SizeRequirement.t()}
  def get_video_sizes do
    Application.get_env(:penguin_memories, :video_sizes)
    |> Enum.map(fn {key, %{} = value} -> {key, struct(SizeRequirement, value)} end)
    |> Enum.into(%{})
  end

  @spec build_photo_dir(Date.t()) :: String.t()
  def build_photo_dir(date) do
    Timex.format!(date, "{YYYY}/{0M}/{0D}")
  end

  @spec build_file_dir(String.t(), String.t(), boolean()) :: String.t()
  def build_file_dir(photo_dir, size_key, is_video) do
    cond do
      size_key == "orig" -> ["orig", photo_dir]
      not is_video and Map.has_key?(get_image_sizes(), size_key) -> ["thumb", size_key, photo_dir]
      is_video and Map.has_key?(get_video_sizes(), size_key) -> ["video", size_key, photo_dir]
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
    image_dir = get_image_dir()
    Path.join([image_dir, file.dir, file.name])
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

  @spec build_new_name(Photo.t(), Media.t()) :: String.t()
  defp build_new_name(%Photo{} = photo, %Media{} = media) do
    extension = Media.get_extension(media)

    photo.name
    |> Path.rootname()
    |> add_extension(extension)
  end

  @spec build_file_from_media(Photo.t(), Media.t(), String.t()) :: {:ok, File.t()}
  def build_file_from_media(%Photo{} = photo, %Media{} = media, size_key) do
    name = build_new_name(photo, media)
    size = Media.get_size(media)
    sha256_hash = Media.get_sha256_hash(media)
    num_bytes = Media.get_num_bytes(media)
    format = Media.get_format(media)
    is_video = Media.is_video(media)

    file_dir = build_file_dir(photo.path, size_key, is_video)

    dest_path = build_path(file_dir, name)
    false = exists?(dest_path)

    {:ok, _} = Media.copy(media, dest_path)

    file = %File{
      size_key: size_key,
      width: size.width,
      height: size.height,
      dir: file_dir,
      name: name,
      is_video: is_video,
      mime_type: format,
      sha256_hash: sha256_hash,
      num_bytes: num_bytes,
      photo_id: photo.id
    }

    {:ok, file}
  end
end
