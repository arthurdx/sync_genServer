defmodule DeviceHandler do
  @behaviour :ranch_protocol
  
  @msg_inventory 0x01
  @msg_pull 0x02
  @msg_ack_ok 0x03
  @msg_ack_error 0x04

  def start_link(ref, transport, opts) do
    pid = spawn_link(__MODULE__, :init, [ref, transport, opts])
    {:ok, pid}
  end

  def init(ref, transport, opts) do
    {:ok, socket} = :ranch.handshake(ref)
    :ok = transport.setopts(socket, [{:active, false}])
    {:ok, <<device_id::8>>} = transport.recv(socket, 1, 5000)
    IO.puts("device #{device_id} connected")
    {:ok, session_pid} = DeviceSupervisor.start_device(DeviceSupervisor, device_id)
    loop(socket, transport, session_pid)
  end

  defp loop(socket, transport, session_pid) do
    case transport.recv(socket, 5, 5000) do 
      {:ok, <<type::8, length::32-little>>} ->
        payload = if length > 0 do
          {:ok, data} = transport.recv(socket, length, 5000)
          data
        else
          <<>>
        end
        IO.puts("received message type: #{type}")
        handle_message(type, payload, socket, transport, session_pid)
        loop(socket, transport, session_pid)
      {:error, reason} ->
        IO.puts("device disconnected: #{reason}")
    end
  end

  defp handle_message(@msg_inventory, payload, socket, transport, session_pid) do
    session_inventory = parse_ids(payload, [])
    DeviceSession.receive_inventory(session_pid, session_inventory)
    state = DeviceSession.get_state(session_pid)
    count = length(state.action_queue)
    transport.send(socket, <<count::32-little>>)
  end
  
  defp handle_message(@msg_pull, _payload, socket, transport, session_pid) do
    action = DeviceSession.next_action(session_pid)
    type_byte = case action.type do
      :upload -> 0x01
      :deploy -> 0x02
      :remove -> 0x03
      nil -> 0x00
    end
    transport.send(socket, <<type_byte::8, action.record_id::binary-size(6)>>)
  end

  defp handle_message(@msg_ack_ok, payload, socket, transport, session_pid) do
    #acknowlege that action was processed
  end

  defp handle_message(@msg_ack_error, payload, socket, transport, session_pid) do
    #ack error put action back in queue
  end

  defp parse_ids(<<id::binary-size(6), rest::binary>>, acc) do
    parse_ids(rest, [id | acc])
  end

  defp parse_ids(<<>>, acc), do: acc

end
