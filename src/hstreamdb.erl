-module(hstreamdb).

-compile([nowarn_unused_vars]).

-on_load(init/0).

-define(NOT_LOADED, not_loaded(?LINE)).
-define(TIMEOUT_EXIT, exit({timeout, {?FUNCTION_NAME, ?FUNCTION_ARITY}})).
-define(SYNC_TIMEOUT, 5000).
-define(ASYNC_TIMEOUT, infinity).

-export([
    start_client/2, start_client/3,
    echo/2, echo/3,
    new_client_tls_config/0,
    set_domain_name/2,
    set_ca_certificate/2,
    set_identity/3,
    create_stream/5, create_stream/6,
    create_subscription/6, create_subscription/7,
    start_producer/3, start_producer/4,
    append/3, append/4,
    await_append_result/1, await_append_result/2,
    start_streaming_fetch/4,
    start_streaming_fetch/5,
    ack/1, ack/2,
    create_shard_reader/6, create_shard_reader/7,
    read_shard/3, read_shard/4
]).
-export([is_record_id/1, shard_id/1, batch_id/1, batch_index/1]).
-export([is_flush_result/1, is_ok/1, batch_len/1, batch_size/1]).

-export_type([
    client_tls_config/0,
    payload_type/0,
    producer/0,
    append_result/0,
    compression_type/0,
    client_setting/0,
    producer_setting/0,
    record_id/0,
    flush_result/0,
    special_offset/0,
    stream_shard_offset/0,
    responder/0,
    streaming_fetch_message/0,
    shard_reader_id/0,
    read_shard_result/0
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
-type client_setting() ::
    {concurrency_limit, pos_integer()} | {tls_config, client_tls_config()}.
-type producer_setting() ::
    {compression_type, compression_type()}
    | {concurrency_limit, pos_integer()}
    | {flow_control_size, pos_integer()}
    | {max_batch_len, non_neg_integer()}
    | {max_batch_size, non_neg_integer()}
    | {batch_deadline, non_neg_integer()}
    | {on_flush, pid()}.
-type special_offset() :: earliest | latest.
-type stream_shard_offset() :: special_offset() | record_id().
-type responder() :: reference().
-type shard_reader_id() :: reference().

-record(record_id, {
    shard_id :: non_neg_integer(),
    batch_id :: non_neg_integer(),
    batch_index :: non_neg_integer()
}).

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

-type client_tls_config() :: reference().

-spec new_client_tls_config() -> client_tls_config().
new_client_tls_config() ->
    ?NOT_LOADED.

-spec set_domain_name(TlsConfig :: client_tls_config(), DomainName :: binary()) ->
    client_tls_config().
set_domain_name(TlsConfig, DomainName) ->
    ?NOT_LOADED.

-spec set_ca_certificate(TlsConfig :: client_tls_config(), CaCertificate :: binary()) ->
    client_tls_config().
set_ca_certificate(TlsConfig, CaCertificate) ->
    ?NOT_LOADED.

-spec set_identity(TlsConfig :: client_tls_config(), Cert :: binary(), Key :: binary()) ->
    client_tls_config().
set_identity(TlsConfig, Cert, Key) ->
    ?NOT_LOADED.

-spec start_client(ServerUrl :: binary(), Options :: [client_setting()]) ->
    {ok, client()} | {error, binary()}.
start_client(ServerUrl, Options) ->
    start_client(ServerUrl, Options, ?SYNC_TIMEOUT).

-spec start_client(
    ServerUrl :: binary(),
    Options :: [client_setting()],
    Timeout :: timeout()
) ->
    {ok, client()} | {error, binary()}.
start_client(ServerUrl, Options, Timeout) ->
    Pid = self(),
    ok = async_start_client(Pid, ServerUrl, Options),
    receive
        {start_client_reply, ok, Client} ->
            {ok, Client};
        {start_client_reply, error, Err} ->
            {error, Err}
    after Timeout ->
        ?TIMEOUT_EXIT
    end.

-spec async_start_client(
    Pid :: pid(),
    ServerUrl :: binary(),
    Options :: [client_setting()]
) ->
    ok | {error, {badarg, binary()}}.
async_start_client(Pid, ServerUrl, Options) ->
    ?NOT_LOADED.

-spec echo(Client :: client(), Msg :: binary()) -> {ok, binary()} | {error, binary()}.
echo(Client, Msg) ->
    echo(Client, Msg, ?SYNC_TIMEOUT).

-spec echo(Client :: client(), Msg :: binary(), Timeout :: timeout()) ->
    {ok, binary()} | {error, binary()}.
echo(Client, Msg, Timeout) ->
    Pid = self(),
    {} = async_echo(Pid, Client, Msg),
    receive
        {echo_reply, ok, Reply} ->
            {ok, Reply};
        {echo_reply, error, Err} ->
            {error, Err}
    after Timeout ->
        ?TIMEOUT_EXIT
    end.

-spec async_echo(Pid :: pid(), Client :: client(), Msg :: binary()) -> {}.
async_echo(Pid, Client, Msg) ->
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
    create_stream(
        Client,
        StreamName,
        ReplicationFactor,
        BacklogDuration,
        ShardCount,
        ?SYNC_TIMEOUT
    ).

-spec create_stream(
    Client :: client(),
    StreamName :: binary(),
    ReplicationFactor :: pos_integer(),
    BacklogDuration :: pos_integer(),
    ShardCount :: pos_integer(),
    Timeout :: timeout()
) ->
    ok | {error, binary()}.
create_stream(
    Client,
    StreamName,
    ReplicationFactor,
    BacklogDuration,
    ShardCount,
    Timeout
) ->
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
    after Timeout ->
        ?TIMEOUT_EXIT
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
    create_subscription(
        Client,
        SubscriptionId,
        StreamName,
        AckTimeoutSeconds,
        MaxUnackedRecords,
        SpecialOffset,
        ?SYNC_TIMEOUT
    ).

-spec create_subscription(
    Client :: client(),
    SubscriptionId :: binary(),
    StreamName :: binary(),
    AckTimeoutSeconds :: pos_integer(),
    MaxUnackedRecords :: pos_integer(),
    SpecialOffset :: special_offset(),
    Timeout :: timeout()
) ->
    ok | {error, {badarg, binary()}} | {error, binary()}.
create_subscription(
    Client,
    SubscriptionId,
    StreamName,
    AckTimeoutSeconds,
    MaxUnackedRecords,
    SpecialOffset,
    Timeout
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
            after Timeout ->
                ?TIMEOUT_EXIT
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
    start_producer(Client, StreamName, ProducerSettings, ?SYNC_TIMEOUT).

-spec start_producer(
    Client :: client(),
    StreamName :: binary(),
    ProducerSettings :: [producer_setting()],
    Timeout :: timeout()
) ->
    {ok, producer()} | {error, binary()}.
start_producer(Client, StreamName, ProducerSettings, Timeout) ->
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
            after Timeout ->
                ?TIMEOUT_EXIT
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

-spec append(Producer :: producer(), PartitionKey :: binary(), RawPayload :: binary()) ->
    {ok, append_result()} | {error, binary()}.
append(Producer, PartitionKey, RawPayload) ->
    append(Producer, PartitionKey, RawPayload, ?ASYNC_TIMEOUT).

-spec append(
    Producer :: producer(),
    PartitionKey :: binary(),
    RawPayload :: binary(),
    Timeout :: timeout()
) ->
    {ok, append_result()} | {error, binary()}.
append(Producer, PartitionKey, RawPayload, Timeout) ->
    Pid = self(),
    {} = async_append(Pid, Producer, PartitionKey, RawPayload),
    receive
        {append_reply, ok, AppendResult} ->
            {ok, AppendResult};
        {append_reply, error, Err} ->
            {error, Err}
    after Timeout ->
        ?TIMEOUT_EXIT
    end.

-spec async_append(
    Pid :: pid(),
    Producer :: producer(),
    PartitionKey :: binary(),
    RawPayload :: binary()
) ->
    {}.
async_append(Pid, Producer, PartitionKey, RawPayload) ->
    ?NOT_LOADED.

-spec await_append_result(AppendResult :: append_result()) ->
    {ok, record_id()} | {error, binary()}.
await_append_result(AppendResult) ->
    await_append_result(AppendResult, ?ASYNC_TIMEOUT).

-spec await_append_result(AppendResult :: append_result(), Timeout :: timeout()) ->
    {ok, record_id()} | {error, binary()}.
await_append_result(AppendResult, Timeout) ->
    Pid = self(),
    {} = async_await_append_result(Pid, AppendResult),
    receive
        {await_append_result_reply, ok, RecordId} ->
            {ok, RecordId};
        {await_append_result_reply, error, Err} ->
            {err, Err}
    after Timeout ->
        ?TIMEOUT_EXIT
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
    start_streaming_fetch(Client, ReturnPid, ConsumerName, SubscriptionId, ?SYNC_TIMEOUT).

-spec start_streaming_fetch(
    Client :: client(),
    ReturnPid :: pid(),
    ConsumerName :: binary(),
    SubscriptionId :: binary(),
    Timeout :: timeout()
) ->
    ok | {error, binary()}.
start_streaming_fetch(Client, ReturnPid, ConsumerName, SubscriptionId, Timeout) ->
    Pid = self(),
    {} = async_start_streaming_fetch(Pid, Client, ReturnPid, ConsumerName, SubscriptionId),
    receive
        {start_streaming_fetch_reply, ok} ->
            ok;
        {start_streaming_fetch_reply, error, Err} ->
            {error, Err}
    after Timeout ->
        ?TIMEOUT_EXIT
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
    ack(Responder, ?SYNC_TIMEOUT).

-spec ack(Responder :: responder(), Timeout :: timeout()) ->
    ok | {error, already_acked} | {error, terminated}.
ack(Responder, Timeout) ->
    Pid = self(),
    async_ack(Pid, Responder),
    receive
        {ack_reply, ok} ->
            ok;
        {ack_reply, error, Err} ->
            {error, Err}
    after Timeout ->
        ?TIMEOUT_EXIT
    end.

-spec async_ack(Pid :: pid(), Responder :: responder()) -> {}.
async_ack(Pid, Responder) ->
    ?NOT_LOADED.

-spec create_shard_reader(
    Client :: client(),
    ReaderId :: binary(),
    StreamName :: binary(),
    ShardId :: non_neg_integer(),
    StreamShardOffset :: stream_shard_offset(),
    TimeoutMs :: pos_integer()
) ->
    {ok, shard_reader_id()}
    | {error, {badarg, binary()}}
    | {error, binary()}.
create_shard_reader(
    Client,
    ReaderId,
    StreamName,
    ShardId,
    StreamShardOffset,
    TimeoutMs
) ->
    create_shard_reader(
        Client,
        ReaderId,
        StreamName,
        ShardId,
        StreamShardOffset,
        TimeoutMs,
        ?SYNC_TIMEOUT
    ).

-spec create_shard_reader(
    Client :: client(),
    ReaderId :: binary(),
    StreamName :: binary(),
    ShardId :: non_neg_integer(),
    StreamShardOffset :: stream_shard_offset(),
    TimeoutMs :: pos_integer(),
    Timeout :: timeout()
) ->
    {ok, shard_reader_id()}
    | {error, {badarg, binary()}}
    | {error, binary()}.
create_shard_reader(
    Client,
    ReaderId,
    StreamName,
    ShardId,
    StreamShardOffset,
    TimeoutMs,
    Timeout
) ->
    Pid = self(),
    case
        async_create_shard_reader(
            Pid,
            Client,
            ReaderId,
            StreamName,
            ShardId,
            StreamShardOffset,
            TimeoutMs
        )
    of
        {error, {badarg, Err}} ->
            {error, {badarg, Err}};
        ok ->
            receive
                {create_shard_reader_reply, ok, ShardReaderId} ->
                    ShardReaderId;
                {create_shard_reader_reply, error, Err} ->
                    {error, Err}
            after Timeout ->
                ?TIMEOUT_EXIT
            end
    end.

-spec async_create_shard_reader(
    Pid :: pid(),
    Client :: client(),
    ReaderId :: binary(),
    StreamName :: binary(),
    ShardId :: non_neg_integer(),
    StreamShardOffset :: stream_shard_offset(),
    TimeoutMs :: pos_integer()
) ->
    ok | {error, {badarg, binary()}}.
async_create_shard_reader(
    Pid,
    Client,
    ReaderId,
    StreamName,
    ShardId,
    StreamShardOffset,
    TimeoutMs
) ->
    ?NOT_LOADED.

-type read_shard_result() ::
    {h_record, binary()} | {raw_record, binary()} | {bad_hstream_record, binary()}.

-spec read_shard(
    Client :: client(),
    ShardReaderId :: shard_reader_id(),
    MaxRecords :: non_neg_integer()
) ->
    {ok, [read_shard_result()]} | {error, binary()}.
read_shard(Client, ShardReaderId, MaxRecords) ->
    read_shard(Client, ShardReaderId, MaxRecords, ?ASYNC_TIMEOUT).

-spec read_shard(
    Client :: client(),
    ShardReaderId :: shard_reader_id(),
    MaxRecords :: non_neg_integer(),
    Timeout :: timeout()
) ->
    {ok, [read_shard_result()]} | {error, binary()}.
read_shard(Client, ShardReaderId, MaxRecords, Timeout) ->
    Pid = self(),
    {} = async_read_shard(Pid, Client, ShardReaderId, MaxRecords),
    receive
        {read_shard_reply, ok, Records} ->
            {ok, Records};
        {read_shard_reply, error, Err} ->
            {error, Err}
    after Timeout ->
        ?TIMEOUT_EXIT
    end.

-spec async_read_shard(
    Pid :: pid(),
    Client :: client(),
    ShardReaderId :: shard_reader_id(),
    MaxRecords :: non_neg_integer()
) ->
    {}.
async_read_shard(Pid, Client, ShardReaderId, MaxRecords) ->
    ?NOT_LOADED.
