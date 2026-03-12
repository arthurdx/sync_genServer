defmodule DeviceSupervisor do
  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_device(sup_pid, device_id) do
    DynamicSupervisor.start_child(sup_pid, {DeviceSession, device_id})
  end
end
