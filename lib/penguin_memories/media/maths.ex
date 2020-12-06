defmodule PenguinMemories.Media.Maths do
  @moduledoc false

  @spec round(float(), integer()) :: integer()
  def round(x, base) do
      base * round(x/base)
  end
end
