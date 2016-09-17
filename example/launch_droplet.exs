alias DigitalOceanExplorations.{DigitalOceanAPI, Launcher}

image = DigitalOceanAPI.image_for_distribution_and_version!("Debian", "8.5 x64")
region =
  DigitalOceanAPI.regions_for_image!(image)
  |> DigitalOceanAPI.maximize_features
  |> DigitalOceanAPI.favor_region(["New York", "San Fran"])
size = DigitalOceanAPI.smallest_size(region)
props = %{
  name: "elixir-launched",
  image: image.slug,
  region: region.slug,
  size: size
}

Launcher.launch_unless_running(props)
