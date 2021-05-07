defmodule PenguinMemories.Media.ToolsTest do
  use ExUnit.Case, async: true

  alias PenguinMemories.Media.Tools

  describe "exif" do
    test "exif works" do
      assert Tools.exif("priv/tests/100x100.jpg")["File:Comment"] == "Created with GIMP"
      assert Tools.exif("priv/tests/100x100.png")["PNG:BitDepth"] == 8
      assert Tools.exif("priv/tests/xcf/100x100.xcf")["GIMP:Comment"] == "Created with GIMP"
      assert Tools.exif("priv/tests/IMG_4706.CR2")["EXIF:ISO"] == 100
      assert Tools.exif("priv/tests/MVI_7254.mp4")["QuickTime:BitDepth"] == 24
      assert Tools.exif("priv/tests/MVI_7254.ogv")["Theora:NominalVideoBitrate"] == 400_000
      assert Tools.exif("priv/tests/MVI_7254.webm")["Matroska:AudioSampleRate"] == 48_000
    end

    test "ffmpeg works" do
      assert Tools.ffprobe("priv/tests/100x100.jpg")["format"]["nb_streams"] == 1
      assert Tools.ffprobe("priv/tests/100x100.png")["format"]["nb_streams"] == 1
      # assert Tools.ffprobe("priv/tests/100x100.xcf")["format"]["nb_streams"] == 1
      assert Tools.ffprobe("priv/tests/IMG_4706.CR2")["format"]["nb_streams"] == 1
      assert Tools.ffprobe("priv/tests/MVI_7254.mp4")["format"]["nb_streams"] == 2
      assert Tools.ffprobe("priv/tests/MVI_7254.ogv")["format"]["nb_streams"] == 2
      assert Tools.ffprobe("priv/tests/MVI_7254.webm")["format"]["nb_streams"] == 2
    end
  end
end
