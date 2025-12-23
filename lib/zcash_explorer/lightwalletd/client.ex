defmodule ZcashExplorer.Lightwalletd.Client do
  use GenServer

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def channel do
    GenServer.call(__MODULE__, :channel)
  end

  def reset do
    GenServer.cast(__MODULE__, :reset)
  end

  @impl true
  def init(_opts) do
    {:ok, %{channel: nil}}
  end

  @impl true
  def handle_call(:channel, _from, %{channel: %GRPC.Channel{} = channel} = state) do
    {:reply, {:ok, channel}, state}
  end

  def handle_call(:channel, _from, state) do
    case connect() do
      {:ok, channel} -> {:reply, {:ok, channel}, %{state | channel: channel}}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast(:reset, state) do
    {:noreply, %{state | channel: nil}}
  end

  defp connect do
    config = Application.get_env(:zcash_explorer, ZcashExplorer.Lightwalletd, [])

    hostname = Keyword.get(config, :hostname)
    port = Keyword.get(config, :port)
    tls = Keyword.get(config, :tls, false)
    cacertfile = Keyword.get(config, :cacertfile)

    with true <- is_binary(hostname) and byte_size(hostname) > 0,
         true <- is_integer(port) and port > 0 do
      target = "#{hostname}:#{port}"
      opts = connection_opts(tls, cacertfile)

      Logger.info("Connecting to lightwalletd at #{target} (tls=#{tls})")
      GRPC.Stub.connect(target, opts)
    else
      _ -> {:error, :lightwalletd_not_configured}
    end
  end

  defp connection_opts(false, _cacertfile), do: []

  defp connection_opts(true, cacertfile) when is_binary(cacertfile) and byte_size(cacertfile) > 0 do
    [cred: GRPC.Credential.new(ssl: [cacertfile: cacertfile])]
  end

  defp connection_opts(true, _cacertfile) do
    [cred: GRPC.Credential.new(ssl: [])]
  end
end

