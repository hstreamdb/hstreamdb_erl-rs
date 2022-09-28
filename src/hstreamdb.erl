-module(hstreamdb).

-compile([nowarn_unused_vars]).

-on_load(init/0).

-define(NOT_LOADED, not_loaded(?LINE)).

-export([
    create_stream/5,
    start_producer/3,
    stop_producer/1,
    append/3,
    await_append_result/1
]).
-export([is_record_id/1, shard_id/1, batch_id/1, batch_index/1]).
-export([is_flush_result/1, is_ok/1, batch_len/1, batch_size/1]).

-export_type([
    producer/0,
    append_result/0,
    compression_type/0,
    producer_setting/0,
    record_id/0,
    flush_result/0
]).

-type producer() :: reference().
-type append_result() :: reference().
-type compression_type() :: none | gzip | zstd.
-type producer_setting() ::
    {compression_type, compression_type()}
    | {concurrency_limit, pos_integer()}
    | {max_batch_len, non_neg_integer()}
    | {max_batch_size, non_neg_integer()}
    | {batch_deadline, non_neg_integer()}
    | {on_flush, pid()}.

-record(record_id, {shard_id, batch_id, batch_index}).

-opaque record_id() :: #record_id{}.

-spec is_record_id(X :: any()) -> boolean().
is_record_id(X) ->
    case X of
        {record_id, ShardId, BatchId, BatchIndex} when
            is_integer(ShardId), is_integer(BatchId), is_integer(BatchIndex)
        ->
            true;
        _ ->
            false
    end.

-spec shard_id(RecordId :: record_id()) -> non_neg_integer().
shard_id(RecordId) ->
    RecordId#record_id.shard_id.

-spec batch_id(RecordId :: record_id()) -> non_neg_integer().
batch_id(RecordId) ->
    RecordId#record_id.batch_id.

-spec batch_index(RecordId :: record_id()) -> non_neg_integer().
batch_index(RecordId) ->
    RecordId#record_id.batch_index.

-record(flush_result, {
    is_ok :: boolean(), batch_len :: non_neg_integer(), batch_size :: non_neg_integer()
}).

-opaque flush_result() :: #flush_result{}.

-spec is_flush_result(X :: any()) -> boolean().
is_flush_result(X) ->
    case X of
        {flush_result, IsOk, BatchLen, BatchSize} when
            is_boolean(IsOk), is_integer(BatchLen), is_integer(BatchSize)
        ->
            true;
        _ ->
            false
    end.

-spec is_ok(FlushResult :: flush_result()) -> boolean().
is_ok(FlushResult) ->
    FlushResult#flush_result.is_ok.

-spec batch_len(FlushResult :: flush_result()) -> non_neg_integer().
batch_len(FlushResult) ->
    FlushResult#flush_result.batch_len.

-spec batch_size(FlushResult :: flush_result()) -> non_neg_integer().
batch_size(FlushResult) ->
    FlushResult#flush_result.batch_size.

init() ->
    case code:priv_dir(hstreamdb_erl) of
        {error, bad_name} ->
            erlang:nif_error(
                {not_loaded, [
                    {module, ?MODULE},
                    {line, ?LINE},
                    {error, priv_dir_bad_application_name}
                ]}
            );
        PrivDir ->
            ok = erlang:load_nif(PrivDir ++ "/" ++ "libhstreamdb_erl_nifs", 0)
    end,
    ok.

not_loaded(Line) ->
    erlang:nif_error({not_loaded, [{module, ?MODULE}, {line, Line}]}).

-spec create_stream(
    ServerUrl :: binary(),
    StreamName :: binary(),
    ReplicationFactor :: pos_integer(),
    BacklogDuration :: pos_integer(),
    ShardCount :: pos_integer()
) ->
    ok | {error, binary()}.
create_stream(ServerUrl, StreamName, ReplicationFactor, BacklogDuration, ShardCount) ->
    ?NOT_LOADED.

-spec start_producer(
    ServerUrl :: binary(),
    StreamName :: binary(),
    ProducerSettings :: [producer_setting()]
) ->
    {ok, producer()} | {error, binary()}.
start_producer(ServerUrl, StreamName, ProducerSettings) ->
    ?NOT_LOADED.

-spec stop_producer(Producer :: producer()) -> ok.
stop_producer(Producer) ->
    ?NOT_LOADED.

-spec append(Producer :: producer(), PartitionKey :: binary(), RawPayload :: binary()) ->
    append_result().
append(Producer, PartitionKey, RawPayload) ->
    ?NOT_LOADED.

-spec await_append_result(AppendResult :: append_result()) ->
    {ok, record_id()} | {error, binary()}.
await_append_result(AppendResult) ->
    ?NOT_LOADED.
