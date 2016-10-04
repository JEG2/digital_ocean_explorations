defmodule DigitalOceanExplorations.Plan do
  defstruct name: nil,
            distribution: "Ubuntu",
            version: "16.04.1 x64",
            command_sets: [ ]

  def new(details) do
    struct(__MODULE__, details)
  end
end
