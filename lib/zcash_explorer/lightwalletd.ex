defmodule ZcashExplorer.Lightwalletd do
  alias Cash.Z.Wallet.Sdk.Rpc.{
    AddressList,
    BlockID,
    BlockRange,
    ChainSpec,
    Empty,
    TransparentAddressBlockFilter,
    TxFilter
  }

  alias Cash.Z.Wallet.Sdk.Rpc.CompactTxStreamer.Stub
  alias ZcashExplorer.Lightwalletd.Client

  def enabled? do
    config = Application.get_env(:zcash_explorer, __MODULE__, [])
    Keyword.get(config, :enabled, true) && is_binary(Keyword.get(config, :hostname)) && is_integer(Keyword.get(config, :port))
  end

  def lightd_info do
    with {:ok, channel} <- Client.channel() do
      Stub.get_lightd_info(channel, %Empty{})
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def latest_block_height do
    with {:ok, channel} <- Client.channel(),
         {:ok, %BlockID{height: height}} <- Stub.get_latest_block(channel, %ChainSpec{}) do
      {:ok, height}
    else
      {:error, reason} ->
        Client.reset()
        {:error, reason}
    end
  end

  def taddress_balance(addresses) when is_binary(addresses), do: taddress_balance([addresses])

  def taddress_balance(addresses) when is_list(addresses) do
    with {:ok, channel} <- Client.channel(),
         request <- %AddressList{addresses: addresses},
         {:ok, balance} <- Stub.get_taddress_balance(channel, request) do
      {:ok, balance}
    else
      {:error, reason} ->
        Client.reset()
        {:error, reason}
    end
  end

  def taddress_transactions(address, start_height, end_height)
      when is_binary(address) and is_integer(start_height) and is_integer(end_height) do
    range =
      %BlockRange{
        start: %BlockID{height: start_height},
        end: %BlockID{height: end_height},
        pool_types: []
      }

    request = %TransparentAddressBlockFilter{address: address, range: range}

    with {:ok, channel} <- Client.channel() do
      Stub.get_taddress_txids(channel, request)
    else
      {:error, reason} ->
        Client.reset()
        {:error, reason}
    end
  end

  def transaction(txid_hex) when is_binary(txid_hex) do
    with {:ok, txid_bytes} <- txid_hex_to_bytes_le(txid_hex),
         {:ok, channel} <- Client.channel(),
         request <- %TxFilter{hash: txid_bytes},
         {:ok, raw_tx} <- Stub.get_transaction(channel, request) do
      {:ok, raw_tx}
    else
      {:error, reason} ->
        Client.reset()
        {:error, reason}
    end
  end

  defp txid_hex_to_bytes_le(txid_hex) do
    txid_hex = String.trim(txid_hex)

    if String.length(txid_hex) == 64 do
      try do
        txid_hex
        |> Base.decode16!(case: :mixed)
        |> :binary.bin_to_list()
        |> Enum.reverse()
        |> :erlang.list_to_binary()
        |> then(&{:ok, &1})
      rescue
        _e in ArgumentError -> {:error, :invalid_txid}
      end
    else
      {:error, :invalid_txid}
    end
  end
end
