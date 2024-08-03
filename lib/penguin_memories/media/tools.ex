defmodule PenguinMemories.Media.Tools do
  @moduledoc "External tools for media stuff"

  @spec exif(String.t()) :: map()
  def exif(path) do
    args = [
      "-G",
      "-j",
      "-n",
      # "-c", "%-.6f",
      path
    ]

    {output, 0} = System.cmd("exiftool", args)
    [result] = Jason.decode!(output)
    result
  end

  @spec ffprobe(String.t()) :: map()
  def ffprobe(path) do
    args = [
      "-v",
      "quiet",
      "-of",
      "json",
      "-show_format",
      "-show_streams",
      path
    ]

    {output, 0} = System.cmd("ffprobe", args)
    Jason.decode!(output)
  end
end
