defmodule DeviceSessionTest do
  use ExUnit.Case

  defp drain_queue(pid) do
    case DeviceSession.next_action(pid) do
      nil ->
        IO.puts("-> Fila vazia, sincronização completa")
        :done
      action ->
        IO.puts("-> Ação processada: #{inspect(action)}")
        drain_queue(pid)
    end
  end

  test "supervisor cria uma sessão de dispositivo dinamicamente" do
    {:ok, sup_pid} = DeviceSupervisor.start_link()
    DeviceSupervisor.start_device(sup_pid, 1)
    DeviceSupervisor.start_device(sup_pid, 2)

    children = Supervisor.which_children(sup_pid)
    assert length(children) == 2
  end

  test "ciclo completo de sincronização" do
    {:ok, sup_pid} = DeviceSupervisor.start_link()
    {:ok, pid} = DeviceSupervisor.start_device(sup_pid, 1)

    DeviceSession.receive_inventory(pid, [10, 20, 30, 40])
    IO.puts("-> Inventário recebido: [10, 20, 30, 40]")

    state = DeviceSession.get_state(pid)
    IO.puts("-> Estado atual: #{state.sync_state}")
    assert state.sync_state == :syncing

    action = DeviceSession.next_action(pid)
    assert action != nil

    drain_queue(pid)

    final_state = DeviceSession.get_state(pid)
    IO.puts("-> Estado final: #{final_state.sync_state}")
    assert final_state.sync_state == :idle
    assert final_state.action_queue == []
  end
end
