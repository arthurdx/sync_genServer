defmodule DeviceHandler do
  @behaviour :ranch_protocol

  def start_link(ref, transport, opts) do
    pid = spawn_link(__MODULE__, :init, [ref, transport, opts])
    {:ok, pid}
  end

  def init(ref, transport, opts) do
    {:ok, socket} = :ranch.handshake(ref)
    :ok = transport.setopts(socket, [{:active, false}])
    IO.puts("device connected")
    loop(socket, transport)
  end

  defp loop(socket, transport) do
    case transport.recv(socket, 0, 5000) do
      {:ok, data} ->
        IO.puts("received")
    end
  end

end
