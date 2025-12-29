defmodule ZcashExplorer.RPC do
  @default_timeout 120_000

  def call(method, params \\ [], timeout \\ @default_timeout) do
    GenServer.call(Zcashex, {:call_endpoint, normalize_method(method), params}, timeout)
  end

  def getblockhash(height) when is_integer(height) and height >= 0 do
    call("getblockhash", [height])
  end

  def getblockheader_by_height(height) when is_integer(height) and height >= 0 do
    with {:ok, hash} <- getblockhash(height) do
      Zcashex.getblockheader(hash)
    end
  end

  def getblock_by_height(height, verbosity \\ 1)
      when is_integer(height) and height >= 0 and verbosity in 0..2 do
    with {:ok, hash} <- getblockhash(height) do
      Zcashex.getblock(hash, verbosity)
    end
  end

  defp normalize_method(method) when is_binary(method), do: method
  defp normalize_method(method) when is_atom(method), do: Atom.to_string(method)
end

