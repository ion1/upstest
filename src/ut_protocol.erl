-module (ut_protocol).
-include ("ut_protocol.hrl").

-export ([pad/2, unpad/1, encode/1, decode/1]).

-ifdef (TEST).
-compile (export_all).
-endif.

pad (BitString, Length) ->
  Format = "~" ++ integer_to_list (-Length) ++ "..\000s",
  list_to_bitstring (lists:flatten (io_lib:format (Format, [BitString]))).

unpad (BitString) -> unpad (BitString, <<>>).

unpad (<<>>, Result) -> Result;
unpad (<<0, _Rest/bytes>>, Result) -> Result;
unpad (<<B, Rest/bytes>>, Result) -> unpad (Rest, <<Result/bytes, B>>).

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
    IPv4AddrLittle/bytes, 0:16#10/unit:8>>.

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
                          status   = Status}.

% Private functions.

encode_protocol (1) -> <<?ut_protocol_1_tag>>;
encode_protocol (2) -> <<?ut_protocol_2_tag>>.

decode_protocol (<<?ut_protocol_1_tag>>) -> 1;
decode_protocol (<<?ut_protocol_2_tag>>) -> 2.

% vim:set et sw=2 sts=2:
