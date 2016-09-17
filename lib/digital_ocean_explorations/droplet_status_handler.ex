defmodule DigitalOceanExplorations.DropletStatusHandler do
  # Client API

  def wait_for_active_status(droplet_id, timeout \\ 10 * 60 * 1_000) do
    GenEvent.add_handler(DigOc.event_manager, __MODULE__, nil)
    GenEvent.call(
      DigOc.event_manager,
      __MODULE__,
      {:listen_for, droplet_id, :active, self}
    )

    receive do
      {^droplet_id, :active} -> :active
      after timeout -> :timeout
    end
  end

  # Server API

  #
  # This handle maintains a map keyed by tuples of droplet IDs and status
  # atoms.  The values are a list of PIDs awaiting notification.  When a specific
  # ID reaches the status it's paired with, all associated PIDs will receive a
  # message of the form `{droplet_id, status}`.
  #
  def init(nil) do
    {:ok, %{ }}
  end

  def handle_call({:listen_for, droplet_id, status, pid}, listeners) do
    new_listeners =
      Map.update(
        listeners,
        {droplet_id, status},
        [pid],
        fn pids -> [pid | pids] end
      )
    {:ok, :ok, new_listeners}
  end

  def handle_event({:achieved_status, droplet_id, status}, listeners) do
    id_and_status = {droplet_id, status}
    {pids, new_listeners} = Map.pop(listeners, id_and_status, [ ])
    Enum.each(pids, fn pid -> send(pid, id_and_status) end)
    {:ok, new_listeners}
  end
  def handle_event(_event, listeners), do: {:ok, listeners}
end
