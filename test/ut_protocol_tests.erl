-module (ut_protocol_tests).
-include ("../src/ut_protocol.hrl").

-compile (export_all).
-include_lib ("eunit/include/eunit.hrl").

-define (M, ut_protocol).

-define (SERVER_NAME,  <<"Uninterruptible Poo Supply">>).
-define (SEGMENT_NAME, <<"42nd floor">>).
-define (SEGMENT_ID,   42).
-define (TIME,         16#43210fed).
-define (IPV4_ADDR,    <<10,20,30,40>>).

constants_test_ () ->
  {"The constants should be correct",
   [?_assertEqual (200,          ?ut_server_port),
    ?_assertEqual (2844,         ?ut_discover_port),
    ?_assertEqual (2845,         ?ut_monitor_port),

    ?_assertEqual (<<0, 0>>,     <<?ut_client_tag>>),
    ?_assertEqual (<<1, 0>>,     <<?ut_server_tag>>),

    ?_assertEqual (<<2, 16#10>>, <<?ut_protocol_1_tag>>),
    ?_assertEqual (<<2, 16#20>>, <<?ut_protocol_2_tag>>),
    ?_assertEqual (2,            ?ut_protocol_length),

    ?_assertEqual (<<0>>,        <<?ut_query_tag>>),
    ?_assertEqual (<<1>>,        <<?ut_response_tag>>),

    ?_assertEqual (<<1>>,        <<?ut_register_tag>>),
    ?_assertEqual (<<4>>,        <<?ut_unregister_tag>>),
    ?_assertEqual (<<5>>,        <<?ut_am_i_there_tag>>),
    ?_assertEqual (<<6>>,        <<?ut_discover_tag>>),

    ?_assertEqual (<<2>>,        <<?ut_shutdown_tag>>),
    ?_assertEqual (<<3>>,        <<?ut_shutdown_cancel_tag>>),
    ?_assertEqual (<<7>>,        <<?ut_get_time_tag>>)]}.

pad_test_ () ->
  {"pad should shorten strings if needed and pad with zero bytes if needed",
   [?_assertEqual (<<"">>,                   ?M:pad (<<"foobar">>, 0)),
    ?_assertEqual (<<"foo">>,                ?M:pad (<<"foobar">>, 3)),
    ?_assertEqual (<<"foobar">>,             ?M:pad (<<"foobar">>, 6)),
    ?_assertEqual (<<"foobar\000\000\000">>, ?M:pad (<<"foobar">>, 9))]}.

unpad_test_ () ->
  {"unpad should remove zero bytes and anything that follows from the string",
   [?_assertEqual (<<"foobar">>, ?M:unpad (<<"foobar">>)),
    ?_assertEqual (<<"foobar">>, ?M:unpad (<<"foobar\000\000\000">>)),
    ?_assertEqual (<<"foobar">>, ?M:unpad (<<"foobar\000baz">>)),
    ?_assertEqual (<<"">>,       ?M:unpad (<<"\000baz">>))]}.

encode_decode_protocol_test_ () ->
  {"encode_protocol, decode_protocol should return correct values",
   [?_assertEqual (<<?ut_protocol_1_tag>>, ?M:encode_protocol (1)),
    ?_assertEqual (<<?ut_protocol_2_tag>>, ?M:encode_protocol (2)),
    ?_assertEqual (1, ?M:decode_protocol (<<?ut_protocol_1_tag>>)),
    ?_assertEqual (2, ?M:decode_protocol (<<?ut_protocol_2_tag>>))]}.

register_test_ () ->
  EncodeTests = lists:map (fun ({Protocol, PaddingLength, PacketLength}) ->
      test_encode (#ut_register_query{protocol   = Protocol,
                                      segment_id = ?SEGMENT_ID,
                                      time       = ?TIME},
                   <<?ut_client_tag, (?M:encode_protocol (Protocol))/bytes,
                     ?ut_register_tag, ?ut_query_tag,
                     ?TIME:32, ?SEGMENT_ID:16, ?TIME:32,
                     0:PaddingLength/unit:8>>,
                   PacketLength) end,
    [{1, 16#10, 16#20}, {2, 16#30, 16#40}]),

  DecodeTests = lists:map (fun ({Protocol, ServerNameLength, PacketLength}) ->
      ExpectedServerName = case ServerNameLength of
        0 -> nil;
        _ -> ?SERVER_NAME end,

      test_decode (#ut_register_response{protocol    = Protocol,
                                         server_name = ExpectedServerName},
                   <<?ut_server_tag, (?M:encode_protocol (Protocol))/bytes,
                     ?ut_register_tag, ?ut_response_tag,
                     0:16#12/unit:8,
                     (?M:pad (?SERVER_NAME, ServerNameLength))/bytes>>,
                   PacketLength) end,
    [{1, 0, 16#18}, {2, 16#40, 16#58}]),

  [EncodeTests, DecodeTests].

unregister_test_ () ->
  EncodeTests = lists:map (fun (Protocol) ->
      test_encode (#ut_unregister_query{protocol = Protocol},
                   <<?ut_client_tag, (?M:encode_protocol (Protocol))/bytes,
                     ?ut_unregister_tag, ?ut_query_tag,
                     0:16#10/unit:8>>,
                   16#16) end,
    [1, 2]),

  DecodeTests = lists:map (fun (Protocol) ->
      test_decode (#ut_unregister_response{protocol = Protocol},
                   <<?ut_server_tag, (?M:encode_protocol (Protocol))/bytes,
                     ?ut_unregister_tag, ?ut_response_tag,
                     0:16#12/unit:8>>,
                   16#18) end,
    [1, 2]),

  [EncodeTests, DecodeTests].

am_i_there_test_ () ->
  IPv4AddrLittle = fun (<<N:32>>) -> <<N:32/little>> end (?IPV4_ADDR),

  EncodeTests = lists:map (fun (Protocol) ->
      test_encode (#ut_am_i_there_query{protocol = Protocol,
                                        ipv4_addr = ?IPV4_ADDR},
                   <<?ut_client_tag, (?M:encode_protocol (Protocol))/bytes,
                     ?ut_am_i_there_tag, ?ut_query_tag,
                     IPv4AddrLittle/bytes,
                     0:16#10/unit:8>>,
                   16#1a) end,
    [1, 2]),

  DecodeTests = lists:map (fun ({Protocol, StatusByte}) ->
      Status = case StatusByte of
        0 -> false;
        _ -> true end,

      test_decode (#ut_am_i_there_response{protocol = Protocol,
                                           status   = Status},
                   <<?ut_server_tag, (?M:encode_protocol (Protocol))/bytes,
                     ?ut_am_i_there_tag, ?ut_response_tag,
                     StatusByte,
                     0:16#11/unit:8>>,
                   16#18) end,
    [{Protocol, StatusByte} || Protocol   <- [1, 2],
                               StatusByte <- [0, 1, 42]]),

  [EncodeTests, DecodeTests].

test_encode (Rec, Expected, Size) ->
  [{"The size of the encoded packet should be correct",
    ?_assertEqual (Size, byte_size (?M:encode (Rec)))},
   {"The encoded packet should match the expected bit string",
    ?_assertEqual (Expected, ?M:encode (Rec))}].

test_decode (Expected, Packet, Size) ->
  [{"The size of the test packet should be correct",
    ?_assertEqual (Size, byte_size (Packet))},
   {"The decoded record should match the expected one",
    ?_assertEqual (Expected, ?M:decode (Packet))}].

% vim:set et sw=2 sts=2:
