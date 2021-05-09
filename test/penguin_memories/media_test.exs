defmodule PenguinMemories.MediaTest do
  use ExUnit.Case, async: true

  alias PenguinMemories.Media

  describe "get_media" do
    test "get_media works for valid file" do
      assert {:ok, %Media{type: "image", subtype: "jpeg"}} =
               Media.get_media("priv/tests/100x100.jpg")

      assert {:ok, %Media{type: "image", subtype: "png"}} =
               Media.get_media("priv/tests/100x100.png")

      assert {:ok, %Media{type: "image", subtype: "cr2"}} =
               Media.get_media("priv/tests/IMG_4706.CR2")

      assert {:ok, %Media{type: "video", subtype: "mp4"}} =
               Media.get_media("priv/tests/MVI_7254.mp4")

      assert {:ok, %Media{type: "video", subtype: "ogg"}} =
               Media.get_media("priv/tests/MVI_7254.ogv")

      assert {:ok, %Media{type: "video", subtype: "webm"}} =
               Media.get_media("priv/tests/MVI_7254.webm")

      assert {:error, _} = Media.get_media("priv/tests/xcf/100x100.xcf")
    end

    test "get_media works fails for non-existant file" do
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.jpg")
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.png")
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.mp4")
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.ogv")
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.webm")
    end
  end

  describe "get_format" do
    test "get_media works for valid file" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      assert Media.get_format(media) == "image/jpeg"
      assert Media.get_extension(media) == "jpg"

      {:ok, media} = Media.get_media("priv/tests/100x100.png")
      assert Media.get_format(media) == "image/png"
      assert Media.get_extension(media) == "png"

      {:ok, media} = Media.get_media("priv/tests/IMG_4706.CR2")
      assert Media.get_format(media) == "image/cr2"
      assert Media.get_extension(media) == "cr2"

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.mp4")
      assert Media.get_format(media) == "video/mp4"
      assert Media.get_extension(media) == "mp4"

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      assert Media.get_format(media) == "video/ogg"
      assert Media.get_extension(media) == "ogv"

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      assert Media.get_format(media) == "video/webm"
      assert Media.get_extension(media) == "webm"
    end

    test "get_media works fails for non-existant file" do
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.jpg")
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.png")
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.mp4")
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.ogv")
      assert {:error, _} = Media.get_media("priv/tests/1000x1000.webm")
    end
  end

  describe "get image type" do
    test "is_image works valid file" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      assert Media.is_image(media) == true

      {:ok, media} = Media.get_media("priv/tests/100x100.png")
      assert Media.is_image(media) == true

      {:ok, media} = Media.get_media("priv/tests/IMG_4706.CR2")
      assert Media.is_image(media) == true

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.mp4")
      assert Media.is_image(media) == false

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      assert Media.is_image(media) == false

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      assert Media.is_image(media) == false
    end

    test "is_video works valid file" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      assert Media.is_video(media) == false

      {:ok, media} = Media.get_media("priv/tests/100x100.png")
      assert Media.is_video(media) == false

      {:ok, media} = Media.get_media("priv/tests/IMG_4706.CR2")
      assert Media.is_video(media) == false

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.mp4")
      assert Media.is_video(media) == true

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      assert Media.is_video(media) == true

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      assert Media.is_video(media) == true
    end
  end

  describe "get_size" do
    test "get_size works valid file" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      assert Media.get_size(media) == %Media.Size{width: 100, height: 100}

      {:ok, media} = Media.get_media("priv/tests/100x100.png")
      assert Media.get_size(media) == %Media.Size{width: 100, height: 100}

      {:ok, media} = Media.get_media("priv/tests/IMG_4706.CR2")
      assert Media.get_size(media) == %Media.Size{width: 3474, height: 2314}

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.mp4")
      assert Media.get_size(media) == %Media.Size{width: 480, height: 270}

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      assert Media.get_size(media) == %Media.Size{width: 480, height: 270}

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      assert Media.get_size(media) == %Media.Size{width: 480, height: 270}
    end

    test "get_new_size works valid file" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")

      sr = %Media.SizeRequirement{max_width: nil, max_height: nil, format: "image/jpeg"}
      assert Media.get_new_size(media, sr) == %Media.Size{width: 100, height: 100}

      sr = %Media.SizeRequirement{max_width: 80, max_height: nil, format: "image/jpeg"}
      assert Media.get_new_size(media, sr) == %Media.Size{width: 80, height: 80}

      sr = %Media.SizeRequirement{max_width: nil, max_height: 80, format: "image/jpeg"}
      assert Media.get_new_size(media, sr) == %Media.Size{width: 80, height: 80}

      sr = %Media.SizeRequirement{max_width: 90, max_height: 80, format: "image/jpeg"}

      assert Media.get_new_size(media, sr) == %Media.Size{
               width: 80,
               height: 80
             }

      sr = %Media.SizeRequirement{max_width: 80, max_height: 90, format: "image/jpeg"}

      assert Media.get_new_size(media, sr) == %Media.Size{
               width: 80,
               height: 80
             }
    end
  end

  describe "resize png file" do
    test "to jpeg" do
      {:ok, media} = Media.get_media("priv/tests/100x100.png")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 20, max_height: 10, format: "image/jpeg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "jpeg"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 10, height: 10}
      Media.delete(new_media)
    end

    test "to png" do
      {:ok, media} = Media.get_media("priv/tests/100x100.png")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 20, max_height: 10, format: "image/png"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "png"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 10, height: 10}
      Media.delete(new_media)
    end

    test "to gif" do
      {:ok, media} = Media.get_media("priv/tests/100x100.png")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 20, max_height: 10, format: "image/gif"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "gif"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 10, height: 10}
      Media.delete(new_media)
    end
  end

  describe "resize jpeg file" do
    test "to jpeg" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 20, max_height: 10, format: "image/jpeg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "jpeg"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 10, height: 10}
      Media.delete(new_media)
    end

    test "to png" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 20, max_height: 10, format: "image/png"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "png"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 10, height: 10}
      Media.delete(new_media)
    end

    test "to gif" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 20, max_height: 10, format: "image/gif"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "gif"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 10, height: 10}
      Media.delete(new_media)
    end
  end

  describe "resize cr2 file" do
    test "to jpeg" do
      {:ok, media} = Media.get_media("priv/tests/IMG_4706.CR2")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/jpeg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "jpeg"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 99, height: 66}
      Media.delete(new_media)
    end

    test "to png" do
      {:ok, media} = Media.get_media("priv/tests/IMG_4706.CR2")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/jpeg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "jpeg"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 99, height: 66}
      Media.delete(new_media)
    end

    test "to gif" do
      {:ok, media} = Media.get_media("priv/tests/IMG_4706.CR2")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/gif"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "gif"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 99, height: 66}
      Media.delete(new_media)
    end
  end

  describe "resize mp4 file" do
    test "to jpeg" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.mp4")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/jpeg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "jpeg"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to png" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.mp4")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/png"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "png"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to gif" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.mp4")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/png"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "png"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to mp4" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "video/mp4"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "video"
      assert new_media.subtype == "mp4"
      assert Media.is_video(new_media) == true
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to ogg" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "video/ogg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "video"
      assert new_media.subtype == "ogg"
      assert Media.is_video(new_media) == true
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to webm" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "video/webm"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "video"
      assert new_media.subtype == "webm"
      assert Media.is_video(new_media) == true
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end
  end

  describe "resize ogg file" do
    test "to jpeg" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/jpeg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "jpeg"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to png" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/png"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "png"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to gif" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/png"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "png"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to mp4" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "video/mp4"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "video"
      assert new_media.subtype == "mp4"
      assert Media.is_video(new_media) == true
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to ogg" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "video/ogg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "video"
      assert new_media.subtype == "ogg"
      assert Media.is_video(new_media) == true
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to webm" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "video/webm"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "video"
      assert new_media.subtype == "webm"
      assert Media.is_video(new_media) == true
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end
  end

  describe "resize webm file" do
    test "to jpeg" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/jpeg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "jpeg"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to png" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/png"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "png"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to gif" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "image/png"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "png"
      assert Media.is_video(new_media) == false
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to mp4" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "video/mp4"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "video"
      assert new_media.subtype == "mp4"
      assert Media.is_video(new_media) == true
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to ogg" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "video/ogg"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "video"
      assert new_media.subtype == "ogg"
      assert Media.is_video(new_media) == true
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end

    test "to webm" do
      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      new_path = Temp.path!()

      sr = %Media.SizeRequirement{max_width: 100, max_height: 100, format: "video/webm"}
      {:ok, new_media} = Media.resize(media, new_path, sr)
      assert new_media.path == new_path
      assert new_media.type == "video"
      assert new_media.subtype == "webm"
      assert Media.is_video(new_media) == true
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 56}
      Media.delete(new_media)
    end
  end

  describe "get_exif" do
    test "get_exif works valid file" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      assert Media.get_exif(media)["File:Comment"] == "Created with GIMP"
    end
  end

  describe "get_datetime" do
    test "get_datetime works valid file" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      %NaiveDateTime{} = Media.get_datetime(media)

      {:ok, media} = Media.get_media("priv/tests/100x100.png")
      %NaiveDateTime{} = Media.get_datetime(media)

      {:ok, media} = Media.get_media("priv/tests/IMG_4706.CR2")
      assert Media.get_datetime(media) == ~N[2005-03-19 10:57:13]

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.mp4")
      %NaiveDateTime{} = Media.get_datetime(media)

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.ogv")
      %NaiveDateTime{} = Media.get_datetime(media)

      {:ok, media} = Media.get_media("priv/tests/MVI_7254.webm")
      %NaiveDateTime{} = Media.get_datetime(media)
    end
  end

  describe "get file details" do
    test "get file details works valid file" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")

      assert Media.get_sha256_hash(media) == <<
               52,
               74,
               73,
               48,
               204,
               56,
               20,
               119,
               103,
               200,
               167,
               227,
               23,
               19,
               86,
               24,
               145,
               21,
               32,
               202,
               47,
               55,
               86,
               149,
               68,
               226,
               60,
               178,
               140,
               206,
               62,
               143
             >>

      assert Media.get_num_bytes(media) == 2917
    end
  end

  describe "copy and delete" do
    test "test copy and delete works valid file" do
      {:ok, media} = Media.get_media("priv/tests/100x100.jpg")
      new_path = Temp.path!()

      {:ok, new_media} = Media.copy(media, new_path)
      assert new_media.path == new_path
      assert new_media.type == "image"
      assert new_media.subtype == "jpeg"
      assert Media.get_size(new_media) == %Media.Size{width: 100, height: 100}

      :ok = Media.delete(new_media)
      {:error, :enoent} = File.stat(new_path)
    end
  end
end
