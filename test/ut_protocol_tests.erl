-module (ut_protocol_tests).
-include ("../src/ut_protocol.hrl").

-compile (export_all).
-include_lib ("eunit/include/eunit.hrl").

-define (M, ut_protocol).

-define (SERVER_NAME,  <<"Uninterruptible Poo Supply">>).
-define (SEGMENT_NAME, <<"42nd floor">>).
-define (SEGMENT,      42).
-define (TIME,         16#43210fed).

constants_test_ () ->
  {"The constants should be correct",
   [?_assertEqual (200,          ?ut_server_port),
    ?_assertEqual (2844,         ?ut_discover_port),
    ?_assertEqual (2845,         ?ut_monitor_port),

    ?_assertEqual (<<0, 0>>,     <<?ut_client_tag>>),
    ?_assertEqual (<<1, 0>>,     <<?ut_server_tag>>),

    ?_assertEqual (<<2, 16#10>>, <<?ut_protocol_1_tag>>),
    ?_assertEqual (<<2, 16#20>>, <<?ut_protocol_2_tag>>),

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
   [?_assertEqual (<<"foo">>,                ?M:pad (<<"foobar">>, 3)),
    ?_assertEqual (<<"foobar">>,             ?M:pad (<<"foobar">>, 6)),
    ?_assertEqual (<<"foobar\000\000\000">>, ?M:pad (<<"foobar">>, 9))]}.

unpad_test_ () ->
  {"unpad should remove zero bytes and anything that follows from the string",
   [?_assertEqual (<<"foobar">>, ?M:unpad (<<"foobar">>)),
    ?_assertEqual (<<"foobar">>, ?M:unpad (<<"foobar\000\000\000">>)),
    ?_assertEqual (<<"foobar">>, ?M:unpad (<<"foobar\000baz">>)),
    ?_assertEqual (<<"">>,       ?M:unpad (<<"\000baz">>))]}.

register_test_ () ->
  [test_encode (#ut_register_query{protocol   = 1,
                                   segment_id = ?SEGMENT,
                                   time       = ?TIME},
                <<?ut_client_tag, ?ut_protocol_1_tag,
                  ?ut_register_tag, ?ut_query_tag,
                  ?TIME:32, ?SEGMENT:16, ?TIME:32, 0:16#10/unit:8>>,
                16#20),
   test_encode (#ut_register_query{protocol   = 2,
                                   segment_id = ?SEGMENT,
                                   time       = ?TIME},
                <<?ut_client_tag, ?ut_protocol_2_tag,
                  ?ut_register_tag, ?ut_query_tag,
                  ?TIME:32, ?SEGMENT:16, ?TIME:32, 0:16#30/unit:8>>,
                16#40),

   test_decode (#ut_register_response{protocol    = 1,
                                      server_name = nil},
                <<?ut_server_tag, ?ut_protocol_1_tag,
                  ?ut_register_tag, ?ut_response_tag,
                  0:16#12/unit:8>>,
                16#18),
   test_decode (#ut_register_response{protocol    = 2,
                                      server_name = ?SERVER_NAME},
                <<?ut_server_tag, ?ut_protocol_2_tag,
                  ?ut_register_tag, ?ut_response_tag,
                  0:16#12/unit:8, (?M:pad (?SERVER_NAME, 16#40))/bytes>>,
                16#58)].

unregister_test_ () ->
  [test_encode (#ut_unregister_query{protocol = 1},
                <<?ut_client_tag, ?ut_protocol_1_tag,
                  ?ut_unregister_tag, ?ut_query_tag,
                  0:16#10/unit:8>>,
                16#16),
   test_encode (#ut_unregister_query{protocol = 2},
                <<?ut_client_tag, ?ut_protocol_2_tag,
                  ?ut_unregister_tag, ?ut_query_tag,
                  0:16#10/unit:8>>,
                16#16),

   test_decode (#ut_unregister_response{protocol = 1},
                <<?ut_server_tag, ?ut_protocol_1_tag,
                  ?ut_unregister_tag, ?ut_response_tag,
                  0:16#12/unit:8>>,
                16#18),
   test_decode (#ut_unregister_response{protocol = 2},
                <<?ut_server_tag, ?ut_protocol_2_tag,
                  ?ut_unregister_tag, ?ut_response_tag,
                  0:16#12/unit:8>>,
                16#18)].

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
