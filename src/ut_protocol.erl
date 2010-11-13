-module (ut_protocol).
-include ("ut_protocol.hrl").

-export ([encode/1, decode/1]).

-ifdef (TEST).
-compile (export_all).
-endif.

% Encode register query.

encode (#ut_register_query{protocol   = Protocol,
                           segment_id = SegmentId,
                           time       = Time}) ->

  PaddingLength = case Protocol of
    1 -> 16#10;
    2 -> 16#30 end,

  <<?ut_client_tag, (encode_protocol (Protocol))/bytes,
    ?ut_register_tag, ?ut_query_tag,
    Time:32, SegmentId:16, Time:32, 0:PaddingLength/unit:8>>;

% Encode unregister query.

encode (#ut_unregister_query{protocol = Protocol}) ->
  <<?ut_client_tag, (encode_protocol (Protocol))/bytes,
    ?ut_unregister_tag, ?ut_query_tag,
    0:16#10/unit:8>>;

% Encode am_i_there query.

encode (#ut_am_i_there_query{protocol = Protocol, ipv4_addr = IPv4Addr}) ->
  IPv4AddrLittle = fun (<<N:32>>) -> <<N:32/little>> end (IPv4Addr),

  <<?ut_client_tag, (encode_protocol (Protocol))/bytes,
    ?ut_am_i_there_tag, ?ut_query_tag,
    IPv4AddrLittle/bytes, 0:16#10/unit:8>>;

% Encode discover query.

encode (#ut_discover_query{protocol = Protocol, each_segment = EachSegment}) ->
  EachSegmentByte = case EachSegment of
    false -> 0;
    true  -> 1 end,

  <<?ut_client_tag, (encode_protocol (Protocol))/bytes,
    ?ut_discover_tag, ?ut_query_tag,
    EachSegmentByte, 0:16#f/unit:8>>;

% Encode shutdown response.

encode (#ut_shutdown_response{protocol       = Protocol,
                              shutdown_delay = ShutdownDelay,
                              unknown_6      = Unknown6,
                              unknown_a      = UnknownA}) ->

  <<?ut_client_tag, (encode_protocol (Protocol))/bytes,
    ?ut_shutdown_tag, ?ut_response_tag,
    Unknown6:16, ShutdownDelay:16, UnknownA, 0:16#11/unit:8>>;

% Encode shutdown_cancel response.

encode (#ut_shutdown_cancel_response{protocol = Protocol}) ->
  <<?ut_client_tag, (encode_protocol (Protocol))/bytes,
    ?ut_shutdown_cancel_tag, ?ut_response_tag, 0:16#10/unit:8>>;

% Encode get_time response.

encode (#ut_get_time_response{protocol = Protocol, time = Time}) ->
  <<?ut_client_tag, (encode_protocol (Protocol))/bytes,
    ?ut_get_time_tag, ?ut_response_tag, Time:32, 0:16#10/unit:8>>.

% Decode register response.

decode (<<?ut_server_tag, ?ut_protocol_1_tag,
          ?ut_register_tag, ?ut_response_tag,
          0:16#12/unit:8>>) ->

  #ut_register_response{protocol    = 1,
                        server_name = nil};

decode (<<?ut_server_tag, ?ut_protocol_2_tag,
          ?ut_register_tag, ?ut_response_tag,
          0:16#12/unit:8, ServerName:16#40/bytes>>) ->

  #ut_register_response{protocol    = 2,
                        server_name = unpad (ServerName)};

% Decode unregister response.

decode (<<?ut_server_tag, Protocol:?ut_protocol_length/bytes,
          ?ut_unregister_tag, ?ut_response_tag,
          0:16#12/unit:8>>) ->

  #ut_unregister_response{protocol = decode_protocol (Protocol)};

% Decode am_i_there response.

decode (<<?ut_server_tag, Protocol:?ut_protocol_length/bytes,
          ?ut_am_i_there_tag, ?ut_response_tag,
          StatusByte, 0:16#11/unit:8>>) ->

  Status = case StatusByte of
    0 -> false;
    _ -> true end,

  #ut_am_i_there_response{protocol = decode_protocol (Protocol),
                          status   = Status};

% Decode discover response.

decode (<<?ut_server_tag, ?ut_protocol_1_tag,
          ?ut_discover_tag, ?ut_response_tag,
          ServerIPv4Addr:32/bits, UnknownA:16, ServerName:16#40/bytes,
          Unknown4C:16#10/unit:8>>) ->

  #ut_discover_response{protocol         = 1,
                        server_ipv4_addr = ServerIPv4Addr,
                        server_name      = unpad (ServerName),
                        have_multip_segs = false,
                        segment_id       = 16#ffff,
                        segment_name     = <<"All">>,
                        unknown_a        = UnknownA,
                        unknown_4c       = Unknown4C};

decode (<<?ut_server_tag, ?ut_protocol_2_tag,
          ?ut_discover_tag, ?ut_response_tag,
          ServerIPv4Addr:32/bits, UnknownA:16, ServerName:16#40/bytes, 0:32,
          HaveMultipSegsByte, 0, SegmentID:16, SegmentName:16#10/bytes>>) ->

  HaveMultipSegs = case HaveMultipSegsByte of
    0 -> false;
    _ -> true end,

  #ut_discover_response{protocol         = 2,
                        server_ipv4_addr = ServerIPv4Addr,
                        server_name      = unpad (ServerName),
                        have_multip_segs = HaveMultipSegs,
                        segment_id       = SegmentID,
                        segment_name     = unpad (SegmentName),
                        unknown_a        = UnknownA};

% Decode shutdown query.

decode (<<?ut_server_tag, Protocol:?ut_protocol_length/bytes,
          ?ut_shutdown_tag, ?ut_query_tag,
          Unknown6:16, Unknown8, 0, ClientID:32/bits, 0:32, Unknown12:16,
          0:16#10/unit:8>>) ->

  #ut_shutdown_query{protocol   = decode_protocol (Protocol),
                     client_id  = ClientID,
                     unknown_6  = Unknown6,
                     unknown_8  = Unknown8,
                     unknown_12 = Unknown12};

% Decode shutdown_cancel query.

decode (<<?ut_server_tag, Protocol:?ut_protocol_length/bytes,
          ?ut_shutdown_cancel_tag, ?ut_query_tag, Unknown6:16#16/unit:8>>) ->

  #ut_shutdown_cancel_query{protocol  = decode_protocol (Protocol),
                            unknown_6 = Unknown6};

% Decode get_time query.

decode (<<?ut_server_tag, Protocol:?ut_protocol_length/bytes,
          ?ut_get_time_tag, ?ut_query_tag, Unknown6:16#10/unit:8>>) ->

  #ut_get_time_query{protocol  = decode_protocol (Protocol),
                     unknown_6 = Unknown6}.

% Private functions.

encode_protocol (1) -> <<?ut_protocol_1_tag>>;
encode_protocol (2) -> <<?ut_protocol_2_tag>>.

decode_protocol (<<?ut_protocol_1_tag>>) -> 1;
decode_protocol (<<?ut_protocol_2_tag>>) -> 2.

client_id (ClientIPv4Addr, MonitorPort, RegisterTime) ->
  Hash = erlang:md5 (<<ClientIPv4Addr:32/bits, MonitorPort:16, RegisterTime:32>>),

  % Take the lowest two bits of the previously inserted byte, or of
  % RegisterTime in the first iteration. Insert the byte from the hash position
  % (count·4 + the value from above).

  {Elems, _} = lists:foldl (fun (I, {Acc, Prev}) ->
      Val = nth_byte (I*4 + (Prev band 3), Hash),
      {[Val|Acc], Val} end,
    {[], RegisterTime}, lists:seq (0, 3)),

  list_to_bitstring (lists:reverse (Elems)).

nth_byte (N, BitString) ->
  <<_Pre:N/bytes, Val, _Post/bytes>> = BitString,
  Val.

pad (BitString, Length) ->
  Format = "~" ++ integer_to_list (-Length) ++ "..\000s",
  list_to_bitstring (lists:flatten (io_lib:format (Format, [BitString]))).

unpad (BitString) -> unpad (BitString, <<>>).

unpad (<<>>,               Result) -> Result;
unpad (<<0, _Rest/bytes>>, Result) -> Result;
unpad (<<B, Rest/bytes>>,  Result) -> unpad (Rest, <<Result/bytes, B>>).

is_localtime_dst (LocalTime) ->
  LocalTimeIfDST = fun (T, DST) ->
    UT = erlang:localtime_to_universaltime (T, DST),
    erlang:universaltime_to_localtime (UT) end,

  LocalTimeNotDST = LocalTimeIfDST (LocalTime, false),
  LocalTimeDST    = LocalTimeIfDST (LocalTime, true),

  % The order is important. If DST doesn’t exist in the timezone, false must be
  % returned.
  case LocalTime of
    LocalTimeNotDST -> false;
    LocalTimeDST    -> true end.

% vim:set et sw=2 sts=2:
