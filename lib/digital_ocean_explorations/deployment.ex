defmodule DigitalOceanExplorations.Deployment do
  defstruct region: "nyc1", size: "512mb"

  def new(details \\ [ ]) do
    struct(__MODULE__, details)
  end
end
