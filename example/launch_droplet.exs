alias DigitalOceanExplorations.{DigitalOceanAPI, Launcher}

ssh_key = DigitalOceanAPI.find_or_create_key!("Elixir Key", fn ->
  "../priv/ssh/id_rsa.pub"
  |> Path.expand(__DIR__)
  |> File.read!
end)
extra_ssh_keys = DigitalOceanAPI.find_keys!(["JEG2's Public Key"])
image = DigitalOceanAPI.image_for_distribution_and_version!("Ubuntu", "16.04.1 x64")
region =
  DigitalOceanAPI.regions_for_image!(image)
  |> DigitalOceanAPI.maximize_features
  |> DigitalOceanAPI.favor_region(["New York", "San Fran"])
size = DigitalOceanAPI.smallest_size(region)
props = %{
  name: "elixir-launched",
  image: image.slug,
  region: region.slug,
  size: size,
  ssh_keys: [ssh_key.id | Enum.map(extra_ssh_keys, fn key -> key.id end)]
}

Launcher.launch_unless_running(props)
