defmodule PenguinMemories.Media.MathsTest do
  use ExUnit.Case, async: true

  alias PenguinMemories.Media.Maths

  describe "round" do
    test "round works" do
      assert Maths.round(0.5, 2) == 0
      assert Maths.round(1.0, 2) == 2
      assert Maths.round(1.5, 2) == 2
      assert Maths.round(2.0, 2) == 2
    end
  end
end
