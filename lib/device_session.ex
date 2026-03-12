defmodule DeviceSession do
 use GenServer

  defmodule Action do
    defstruct type: nil, device_id: nil, record_id: nil
  end

  def start_link(device_id) do
    GenServer.start_link(DeviceSession, device_id)
  end

  def next_action(pid), do: GenServer.call(pid, :next_action)

  def get_state(pid), do: GenServer.call(pid, :get_state)

  def ack_action(pid, record_id, result), do: GenServer.cast(pid, {result, record_id})

  def receive_inventory(pid, inventory), do: GenServer.cast(pid, {:receive_inventory, inventory})

  @impl true
  def init(device_id) do
    IO.puts("DeviceSession #{device_id} started")
    {:ok, %{device_id: device_id, sync_state: :waiting_inventory, action_queue: []}}
  end

  @impl true
  def handle_cast({:receive_inventory, device_inventory}, state) do
    diff = calculate_diff(device_inventory)
    upload_actions = diff.upload |> MapSet.to_list()
      |> Enum.map(fn id -> %Action{type: :upload, device_id: 1, record_id: id} end)
    deploy_actions = diff.deploy |> MapSet.to_list()
      |> Enum.map(fn id -> %Action{type: :deploy, device_id: 1, record_id: id} end)
    remove_actions = diff.remove |> MapSet.to_list()
      |> Enum.map(fn id -> %Action{type: :remove, device_id: 1, record_id: id} end)
    actions = upload_actions ++ deploy_actions ++ remove_actions
    new_state = %{state | action_queue: actions, sync_state: :syncing}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:ok, record_id}, state) do
    IO.puts("Action #{record_id} succeeded")
    {:noreply, state}
  end

  def handle_cast({:error, record_id}, state) do
    IO.puts("Action #{record_id} failed")
    {:noreply, state}
  end

  @impl true
  def handle_call(:next_action, _from, %{action_queue: [next | remaining]} = state) do
    new_state = %{state | action_queue: remaining}
    {:reply, next, new_state}
  end

  @impl true
  def handle_call(:next_action, _from, %{action_queue: []} = state) do
    new_state = %{state | sync_state: :idle}
    {:reply, nil, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  defp calculate_diff(device_inventory) do
    device_ids = MapSet.new(device_inventory)
    server_records = [
      %{id: <<0, 0, 0, 0, 0, 1>>, deleted: false},
      %{id: <<0, 0, 0, 0, 0, 2>>, deleted: true},
      %{id: <<0, 0, 0, 0, 0, 3>>, deleted: false},
      %{id: <<0, 0, 0, 0, 0, 4>>, deleted: true},
      %{id: <<0, 0, 0, 0, 0, 5>>, deleted: false},
    ]

    server_ids = server_records |> MapSet.new(fn record -> record.id end)
    upload     = MapSet.difference(device_ids, server_ids)
    deploy     = MapSet.difference(server_ids, device_ids)
    remove     = server_records |> Enum.filter(fn record -> record.deleted == true end)
      |> MapSet.new(fn record -> record.id end) |> MapSet.intersection(device_ids)

    %{server_ids: server_ids,upload: upload, deploy: deploy, remove: remove}
  end 
end
