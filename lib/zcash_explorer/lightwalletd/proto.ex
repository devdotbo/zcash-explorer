defmodule Cash.Z.Wallet.Sdk.Rpc.PoolType do
  use Protobuf, enum: true, syntax: :proto3

  field :POOL_TYPE_INVALID, 0
  field :TRANSPARENT, 1
  field :SAPLING, 2
  field :ORCHARD, 3
end

defmodule Cash.Z.Wallet.Sdk.Rpc.BlockID do
  use Protobuf, syntax: :proto3

  field :height, 1, type: :uint64
  field :hash, 2, type: :bytes
end

defmodule Cash.Z.Wallet.Sdk.Rpc.BlockRange do
  use Protobuf, syntax: :proto3

  field :start, 1, type: Cash.Z.Wallet.Sdk.Rpc.BlockID
  field :end, 2, type: Cash.Z.Wallet.Sdk.Rpc.BlockID
  field :pool_types, 3, repeated: true, type: Cash.Z.Wallet.Sdk.Rpc.PoolType, enum: true
end

defmodule Cash.Z.Wallet.Sdk.Rpc.TransparentAddressBlockFilter do
  use Protobuf, syntax: :proto3

  field :address, 1, type: :string
  field :range, 2, type: Cash.Z.Wallet.Sdk.Rpc.BlockRange
end

defmodule Cash.Z.Wallet.Sdk.Rpc.Address do
  use Protobuf, syntax: :proto3

  field :address, 1, type: :string
end

defmodule Cash.Z.Wallet.Sdk.Rpc.AddressList do
  use Protobuf, syntax: :proto3

  field :addresses, 1, repeated: true, type: :string
end

defmodule Cash.Z.Wallet.Sdk.Rpc.Balance do
  use Protobuf, syntax: :proto3

  field :value_zat, 1, type: :int64, json_name: "valueZat"
end

defmodule Cash.Z.Wallet.Sdk.Rpc.ChainSpec do
  use Protobuf, syntax: :proto3
end

defmodule Cash.Z.Wallet.Sdk.Rpc.TxFilter do
  use Protobuf, syntax: :proto3

  field :block, 1, type: Cash.Z.Wallet.Sdk.Rpc.BlockID
  field :index, 2, type: :uint64
  field :hash, 3, type: :bytes
end

defmodule Cash.Z.Wallet.Sdk.Rpc.RawTransaction do
  use Protobuf, syntax: :proto3

  field :data, 1, type: :bytes
  field :height, 2, type: :uint64
end

defmodule Cash.Z.Wallet.Sdk.Rpc.Empty do
  use Protobuf, syntax: :proto3
end

defmodule Cash.Z.Wallet.Sdk.Rpc.LightdInfo do
  use Protobuf, syntax: :proto3

  field :version, 1, type: :string
  field :vendor, 2, type: :string
  field :taddr_support, 3, type: :bool, json_name: "taddrSupport"
  field :chain_name, 4, type: :string, json_name: "chainName"
  field :sapling_activation_height, 5, type: :uint64, json_name: "saplingActivationHeight"
  field :consensus_branch_id, 6, type: :string, json_name: "consensusBranchId"
  field :block_height, 7, type: :uint64, json_name: "blockHeight"
  field :git_commit, 8, type: :string, json_name: "gitCommit"
  field :branch, 9, type: :string
  field :build_date, 10, type: :string, json_name: "buildDate"
  field :build_user, 11, type: :string, json_name: "buildUser"
  field :estimated_height, 12, type: :uint64, json_name: "estimatedHeight"
  field :zcashd_build, 13, type: :string, json_name: "zcashdBuild"
  field :zcashd_subversion, 14, type: :string, json_name: "zcashdSubversion"
  field :donation_address, 15, type: :string, json_name: "donationAddress"
  field :upgrade_name, 16, type: :string, json_name: "upgradeName"
  field :upgrade_height, 17, type: :uint64, json_name: "upgradeHeight"
  field :lightwallet_protocol_version, 18, type: :string, json_name: "lightwalletProtocolVersion"
end

defmodule Cash.Z.Wallet.Sdk.Rpc.GetTaddressTxidsPaginatedArg do
  use Protobuf, syntax: :proto3

  field :address, 1, type: :string
  field :start_height, 2, type: :uint64, json_name: "startHeight"
  field :end_height, 3, type: :uint64, json_name: "endHeight"
  field :max_entries, 4, type: :uint32, json_name: "maxEntries"
  field :reverse, 5, type: :bool
end

defmodule Cash.Z.Wallet.Sdk.Rpc.PaginatedTxidsResponse do
  use Protobuf, syntax: :proto3

  field :transaction, 1, type: Cash.Z.Wallet.Sdk.Rpc.RawTransaction
  field :block_height, 2, type: :uint64, json_name: "blockHeight"
  field :tx_index, 3, type: :uint32, json_name: "txIndex"
  field :total_count, 4, type: :uint64, json_name: "totalCount"
  field :txid, 5, type: :bytes
end

defmodule Cash.Z.Wallet.Sdk.Rpc.CompactTxStreamer.Service do
  use GRPC.Service, name: "cash.z.wallet.sdk.rpc.CompactTxStreamer"

  rpc :GetLatestBlock, Cash.Z.Wallet.Sdk.Rpc.ChainSpec, Cash.Z.Wallet.Sdk.Rpc.BlockID
  rpc :GetTransaction, Cash.Z.Wallet.Sdk.Rpc.TxFilter, Cash.Z.Wallet.Sdk.Rpc.RawTransaction

  rpc :GetTaddressTransactions,
      Cash.Z.Wallet.Sdk.Rpc.TransparentAddressBlockFilter,
      stream(Cash.Z.Wallet.Sdk.Rpc.RawTransaction)

  rpc :GetTaddressTxids,
      Cash.Z.Wallet.Sdk.Rpc.TransparentAddressBlockFilter,
      stream(Cash.Z.Wallet.Sdk.Rpc.RawTransaction)

  rpc :GetTaddressBalance, Cash.Z.Wallet.Sdk.Rpc.AddressList, Cash.Z.Wallet.Sdk.Rpc.Balance
  rpc :GetLightdInfo, Cash.Z.Wallet.Sdk.Rpc.Empty, Cash.Z.Wallet.Sdk.Rpc.LightdInfo

  rpc :GetTaddressTxidsPaginated,
      Cash.Z.Wallet.Sdk.Rpc.GetTaddressTxidsPaginatedArg,
      stream(Cash.Z.Wallet.Sdk.Rpc.PaginatedTxidsResponse)
end

defmodule Cash.Z.Wallet.Sdk.Rpc.CompactTxStreamer.Stub do
  use GRPC.Stub, service: Cash.Z.Wallet.Sdk.Rpc.CompactTxStreamer.Service
end

