-module (ut_protocol).
-include ("ut_protocol.hrl").

-export ([encode/1, decode/1, encode_now/1, client_id/3]).

-ifdef (TEST).
-compile (export_all).
-endif.

-compile ({parse_transform, ut_protocol_parse_transform}).

coders () ->
  % From client: register.

  {#ut_register_query{protocol = '$0', segment_id = SegmentId, time = Time},
   <<?ut_client_tag, '$+1', ?ut_register_tag, ?ut_query_tag,
     Time:32, SegmentId:16, Time:32, 0:'$2'/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>, 16#10], [2, <<?ut_protocol_2_tag>>, 16#30]]},

  {#ut_register_response{protocol = 1, server_name = nil},
   <<?ut_server_tag, ?ut_protocol_1_tag, ?ut_register_tag, ?ut_response_tag,
     0:16#12/unit:8>>},
  {#ut_register_response{protocol = 2, server_name = ServerName},
   <<?ut_server_tag, ?ut_protocol_2_tag, ?ut_register_tag, ?ut_response_tag,
     0:16#12/unit:8, ServerNameT:16#40/bytes>>,
   [],
   [{ServerName,
     fun (S) -> pad (S, 16#40) end,
     fun (S) -> unpad (S) end}]},

  % From client: unregister.

  {#ut_unregister_query{protocol = '$0'},
   <<?ut_client_tag, '$+1', ?ut_unregister_tag, ?ut_query_tag,
     0:16#10/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]]},

  {#ut_unregister_response{protocol = '$0'},
   <<?ut_server_tag, '$+1', ?ut_unregister_tag, ?ut_response_tag,
     0:16#12/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]]},

  % From client: am_i_there.

  {#ut_am_i_there_query{protocol = '$0', ipv4_addr = IPv4Addr},
   <<?ut_client_tag, '$+1', ?ut_am_i_there_tag, ?ut_query_tag,
     IPv4AddrT:32/bits, 0:16#10/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]],
   [{IPv4Addr,
     fun (<<N:32>>) -> <<N:32/little>> end,
     fun (<<N:32/little>>) -> <<N:32>> end}]},

  {#ut_am_i_there_response{protocol = '$0', status = Status},
   <<?ut_server_tag, '$+1', ?ut_am_i_there_tag, ?ut_response_tag,
     StatusT, 0:16#11/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]],
   [{Status,
     fun (false) -> 0; (true) -> 1 end,
     fun (0) -> false; (_) -> true end}]},

  % From client: discover.

  {#ut_discover_query{protocol = '$0', each_segment = EachSegment},
   <<?ut_client_tag, '$+1', ?ut_discover_tag, ?ut_query_tag,
     EachSegmentT, 0:16#f/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]],
   [{EachSegment,
     fun (false) -> 0; (true) -> 1 end,
     fun (0) -> false; (_) -> true end}]},

  {#ut_discover_response{protocol         = 1,
                         server_ipv4_addr = ServerIPv4Addr,
                         server_name      = ServerName,
                         have_multip_segs = false,
                         segment_id       = 16#ffff,
                         segment_name     = <<"All">>,
                         unknown_a        = UnknownA,
                         unknown_4c       = Unknown4C},
   <<?ut_server_tag, ?ut_protocol_1_tag, ?ut_discover_tag, ?ut_response_tag,
     ServerIPv4Addr:32/bits, UnknownA:16, ServerNameT:16#40/bytes,
     Unknown4C:16#10/unit:8>>,
   [],
   [{ServerName,
     fun (S) -> pad (S, 16#40) end,
     fun (S) -> unpad (S) end}]},
  {#ut_discover_response{protocol         = 2,
                         server_ipv4_addr = ServerIPv4Addr,
                         server_name      = ServerName,
                         have_multip_segs = HaveMultipSegs,
                         segment_id       = SegmentID,
                         segment_name     = SegmentName,
                         unknown_a        = UnknownA},
   <<?ut_server_tag, ?ut_protocol_2_tag, ?ut_discover_tag, ?ut_response_tag,
     ServerIPv4Addr:32/bits, UnknownA:16, ServerNameT:16#40/bytes, 0:32,
     HaveMultipSegsT, 0, SegmentID:16, SegmentNameT:16#10/bytes>>,
   [],
   [{ServerName,
     fun (S) -> pad (S, 16#40) end,
     fun (S) -> unpad (S) end},
    {HaveMultipSegs,
     fun (false) -> 0; (true) -> 1 end,
     fun (0) -> false; (_) -> true end},
    {SegmentName,
     fun (S) -> pad (S, 16#10) end,
     fun (S) -> unpad (S) end}]},

  % From server: shutdown.

  {#ut_shutdown_query{protocol   = '$0',
                      client_id  = ClientID,
                      unknown_6  = Unknown6,
                      unknown_8  = Unknown8,
                      unknown_12 = Unknown12},
   <<?ut_server_tag, '$+1', ?ut_shutdown_tag, ?ut_query_tag,
     Unknown6:16, Unknown8, 0, ClientID:32/bits, 0:32, Unknown12:16,
     0:16#10/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]]},

  {#ut_shutdown_response{protocol = '$0',
                         shutdown_delay = ShutdownDelay,
                         unknown_6 = Unknown6,
                         unknown_a = UnknownA},
   <<?ut_client_tag, '$+1', ?ut_shutdown_tag, ?ut_response_tag,
     Unknown6:16, ShutdownDelay:16, UnknownA, 0:16#11/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]]},

  % From server: shutdown_cancel.

  {#ut_shutdown_cancel_query{protocol = '$0', unknown_6 = Unknown6},
   <<?ut_server_tag, '$+1', ?ut_shutdown_cancel_tag, ?ut_query_tag,
     Unknown6:16#16/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]]},

  {#ut_shutdown_cancel_response{protocol = '$0'},
   <<?ut_client_tag, '$+1', ?ut_shutdown_cancel_tag, ?ut_response_tag,
     0:16#10/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]]},

  % From server: get_time.

  {#ut_get_time_query{protocol = '$0', unknown_6 = Unknown6},
   <<?ut_server_tag, '$+1', ?ut_get_time_tag, ?ut_query_tag,
     Unknown6:16#10/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]]},

  {#ut_get_time_response{protocol = '$0', time = Time},
   <<?ut_client_tag, '$+1', ?ut_get_time_tag, ?ut_response_tag,
     Time:32, 0:16#10/unit:8>>,
   [[1, <<?ut_protocol_1_tag>>], [2, <<?ut_protocol_2_tag>>]]}.

% Return epoch seconds shifted by DST.
encode_now (Now) ->
  LocalTime = calendar:now_to_local_time (Now),
  Shift = case is_localtime_dst (LocalTime) of
    false -> 0;
    true  -> 60*60 end,

  {MegaS, S, _MicroS} = Now,
  1000000*MegaS + S + Shift.

% Generate a client ID matching what the UPS does.
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

% Private functions.

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
