-module(hstreamdb).

-compile([nowarn_unused_vars]).

-on_load(init/0).

-define(NOT_LOADED, not_loaded(?LINE)).

-export([
    start_client/2,
    create_stream/5,
    create_subscription/6,
    start_producer/3,
    stop_producer/1,
    append/3,
    await_append_result/1,
    start_streaming_fetch/4,
    ack/1
]).
-export([is_record_id/1, shard_id/1, batch_id/1, batch_index/1]).
-export([is_flush_result/1, is_ok/1, batch_len/1, batch_size/1]).

-export_type([
    payload_type/0,
    producer/0,
    append_result/0,
    compression_type/0,
    producer_setting/0,
    record_id/0,
    flush_result/0,
    append_error/0,
    special_offset/0,
    responder/0,
    streaming_fetch_message/0
]).

init() ->
    PrivPath = priv_path(),
    case erlang:load_nif(PrivPath, 0) of
        ok ->
            ok;
        Err ->
            erlang:nif_error(
                {not_loaded, [
                    {error, Err},
                    {module, ?MODULE},
                    {line, ?LINE},
                    {priv_path, PrivPath}
                ]}
            )
    end,
    ok.

priv_path() ->
    Lib = "libhstreamdb_erl_nifs",
    case code:priv_dir(hstreamdb_erl) of
        {error, bad_name} ->
            Dir = filename:dirname(
                code:which(?MODULE)
            ),
            filename:join([filename:dirname(Dir), "priv", Lib]);
        PrivDir ->
            filename:join(PrivDir, Lib)
    end.

not_loaded(Line) ->
    erlang:nif_error({not_loaded, [{module, ?MODULE}, {line, Line}]}).

-type client() :: reference().
-type payload_type() :: h_record | raw_record.
-type producer() :: reference().
-type append_result() :: reference().
-type compression_type() :: none | gzip | zstd.
-type producer_setting() ::
    {compression_type, compression_type()}
    | {concurrency_limit, pos_integer()}
    | {flow_control_size, pos_integer()}
    | {max_batch_len, non_neg_integer()}
    | {max_batch_size, non_neg_integer()}
    | {batch_deadline, non_neg_integer()}
    | {on_flush, pid()}.
-type special_offset() :: earliest | latest.
-type responder() :: reference().

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

-spec start_client(ServerUrl :: binary(), Options :: proplists:proplist()) ->
    {ok, client()} | {error, binary()}.
start_client(ServerUrl, Options) ->
    Pid = self(),
    {} = async_start_client(Pid, ServerUrl, Options),
    receive
        {start_client_reply, ok, Client} ->
            {ok, Client};
        {start_client_reply, error, Err} ->
            {error, Err}
    end.

-spec async_start_client(
    Pid :: pid(),
    ServerUrl :: binary(),
    Options :: proplists:proplist()
) ->
    {}.
async_start_client(Pid, ServerUrl, Options) ->
    ?NOT_LOADED.

-spec create_stream(
    Client :: client(),
    StreamName :: binary(),
    ReplicationFactor :: pos_integer(),
    BacklogDuration :: pos_integer(),
    ShardCount :: pos_integer()
) ->
    ok | {error, binary()}.
create_stream(Client, StreamName, ReplicationFactor, BacklogDuration, ShardCount) ->
    Pid = self(),
    {} =
        async_create_stream(
            Pid,
            Client,
            StreamName,
            ReplicationFactor,
            BacklogDuration,
            ShardCount
        ),
    receive
        {create_stream_reply, ok} ->
            ok;
        {create_stream_reply, error, Err} ->
            {error, Err}
    end.

-spec async_create_stream(
    Pid :: pid(),
    Client :: client(),
    StreamName :: binary(),
    ReplicationFactor :: pos_integer(),
    BacklogDuration :: pos_integer(),
    ShardCount :: pos_integer()
) ->
    {}.
async_create_stream(
    Pid,
    Client,
    StreamName,
    ReplicationFactor,
    BacklogDuration,
    ShardCount
) ->
    ?NOT_LOADED.

-spec create_subscription(
    Client :: client(),
    SubscriptionId :: binary(),
    StreamName :: binary(),
    AckTimeoutSeconds :: pos_integer(),
    MaxUnackedRecords :: pos_integer(),
    SpecialOffset :: special_offset()
) ->
    ok | {error, {badarg, binary()}} | {error, binary()}.
create_subscription(
    Client,
    SubscriptionId,
    StreamName,
    AckTimeoutSeconds,
    MaxUnackedRecords,
    SpecialOffset
) ->
    Pid = self(),
    case
        async_create_subscription(
            Pid,
            Client,
            SubscriptionId,
            StreamName,
            AckTimeoutSeconds,
            MaxUnackedRecords,
            SpecialOffset
        )
    of
        {error, {badarg, Err}} ->
            {error, {badarg, Err}};
        ok ->
            receive
                {create_subscription_reply, ok} ->
                    ok;
                {create_subscription_reply, error, Err} ->
                    {error, Err}
            end
    end.

-spec async_create_subscription(
    Pid :: pid(),
    Client :: client(),
    SubscriptionId :: binary(),
    StreamName :: binary(),
    AckTimeoutSeconds :: pos_integer(),
    MaxUnackedRecords :: pos_integer(),
    SpecialOffset :: special_offset()
) ->
    ok | {error, {badarg, binary()}}.
async_create_subscription(
    Pid,
    Client,
    SubscriptionId,
    StreamName,
    AckTimeoutSeconds,
    MaxUnackedRecords,
    SpecialOffset
) ->
    ?NOT_LOADED.

-spec start_producer(
    Client :: client(),
    StreamName :: binary(),
    ProducerSettings :: [producer_setting()]
) ->
    {ok, producer()} | {error, binary()}.
start_producer(Client, StreamName, ProducerSettings) ->
    Pid = self(),
    case async_start_producer(Pid, Client, StreamName, ProducerSettings) of
        {error, Err} ->
            {error, Err};
        ok ->
            receive
                {start_producer_reply, ok, Producer} ->
                    {ok, Producer};
                {start_producer_reply, error, Err} ->
                    {error, Err}
            end
    end.

-spec async_start_producer(
    Pid :: pid(),
    Client :: client(),
    StreamName :: binary(),
    ProducerSettings :: [producer_setting()]
) ->
    ok | {error, binary()}.
async_start_producer(Pid, Client, StreamName, ProducerSettings) ->
    ?NOT_LOADED.

-spec stop_producer(Producer :: producer()) -> ok | {error, terminated}.
stop_producer(Producer) ->
    Pid = self(),
    {} = async_stop_producer(Pid, Producer),
    receive
        {stop_producer_reply, ok} ->
            ok;
        {stop_producer_reply, error, terminated} ->
            {error, terminated}
    end.

-spec async_stop_producer(Pid :: pid(), Producer :: producer()) -> {}.
async_stop_producer(Pid, Producer) ->
    ?NOT_LOADED.

-type append_error() :: {badarg, binary()} | terminated.

-spec append(Producer :: producer(), PartitionKey :: binary(), RawPayload :: binary()) ->
    {ok, append_result()} | {error, append_error()}.
append(Producer, PartitionKey, RawPayload) ->
    Pid = self(),
    case async_append(Pid, Producer, PartitionKey, RawPayload) of
        Err = {error, {badarg, _}} ->
            Err;
        ok ->
            receive
                {append_reply, ok, AppendResult} ->
                    {ok, AppendResult};
                {append_result, error, terminated} ->
                    {error, terminated}
            end
    end.

-spec async_append(
    Pid :: pid(),
    Producer :: producer(),
    PartitionKey :: binary(),
    RawPayload :: binary()
) ->
    ok | {error, append_error()}.
async_append(Pid, Producer, PartitionKey, RawPayload) ->
    ?NOT_LOADED.

-spec await_append_result(AppendResult :: append_result()) ->
    {ok, record_id()} | {error, binary()}.
await_append_result(AppendResult) ->
    Pid = self(),
    {} = async_await_append_result(Pid, AppendResult),
    receive
        {await_append_result_reply, ok, RecordId} ->
            {ok, RecordId};
        {await_append_result_reply, error, Err} ->
            {err, Err}
    end.

-spec async_await_append_result(Pid :: pid(), AppendResult :: append_result()) -> {}.
async_await_append_result(Pid, AppendResult) ->
    ?NOT_LOADED.

-spec start_streaming_fetch(
    Client :: client(),
    ReturnPid :: pid(),
    ConsumerName :: binary(),
    SubscriptionId :: binary()
) ->
    ok | {error, binary()}.
start_streaming_fetch(Client, ReturnPid, ConsumerName, SubscriptionId) ->
    Pid = self(),
    {} = async_start_streaming_fetch(Pid, Client, ReturnPid, ConsumerName, SubscriptionId),
    receive
        {start_streaming_fetch_reply, ok} ->
            ok;
        {start_streaming_fetch_reply, error, Err} ->
            {error, Err}
    end.

-type streaming_fetch_message() ::
    {streaming_fetch, ConsumerName :: binary(), reply, payload_type(), Payload :: binary(),
        responder()}
    | {streaming_fetch, ConsumerName :: binary(), eos}.

-spec async_start_streaming_fetch(
    Pid :: pid(),
    Client :: client(),
    ReturnPid :: pid(),
    ConsumerName :: binary(),
    SubscriptionId :: binary()
) ->
    {}.
async_start_streaming_fetch(Pid, Client, ReturnPid, ConsumerName, SubscriptionId) ->
    ?NOT_LOADED.

-spec ack(Responder :: responder()) -> ok | {error, already_acked} | {error, terminated}.
ack(Responder) ->
    Pid = self(),
    async_ack(Pid, Responder),
    receive
        {ack_reply, ok} ->
            ok;
        {ack_reply, error, Err} ->
            {error, Err}
    end.

-spec async_ack(Pid :: pid(), Responder :: responder()) -> {}.
async_ack(Pid, Responder) ->
    ?NOT_LOADED.
