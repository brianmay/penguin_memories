defmodule PenguinMemories.Storage do
  @moduledoc """
  Helper functions for storage of media objects on filesystem.
  """
  alias PenguinMemories.Media.SizeRequirement
  alias PenguinMemories.Photos.File

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

  @spec build_filename(String.t(), String.t()) :: String.t()
  def build_filename(new_dir, new_name) do
    Path.join([get_image_dir(), new_dir, new_name])
  end

  @spec get_photo_file_path(File.t()) :: String.t()
  def get_photo_file_path(%File{} = photo) do
    image_dir = get_image_dir()
    Path.join([image_dir, photo.dir, photo.name])
  end
end
