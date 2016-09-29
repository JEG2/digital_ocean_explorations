defmodule DigitalOceanExplorations.AbstractCommand do
  defstruct name: nil, arguments: [ ]

  def new(details) do
    struct(__MODULE__, details)
  end
end
