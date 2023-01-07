defmodule Eventize.Eventstore.EventStoreDB.StoredSnapshot do
  @moduledoc """
  Represents a snapshot stored in EventStoreDB with payload, meta data, version and sequence number.
  """

  alias Eventize.Eventstore.EventStoreDB.StoredSnapshot
  alias Eventize.Persistence.EventStore.SnapshotData

  defstruct [:payload, :meta_data, :version, :sequence_number]

  def to_snapshot_data(%StoredSnapshot{
        payload: payload,
        meta_data: meta_data,
        version: version
      }) do
    %SnapshotData{
      payload: payload,
      meta_data: meta_data,
      version: version
    }
  end
end
