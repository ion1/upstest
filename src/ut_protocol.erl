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

encode (#ut_register_query{protocol   = Protocol,
                           segment_id = SegmentId,
                           time       = Time}) ->

  {ProtocolTag, Padding} = case Protocol of
    1 -> {<<?ut_protocol_1_tag>>, <<0:16#10/unit:8>>};
    2 -> {<<?ut_protocol_2_tag>>, <<0:16#30/unit:8>>} end,

  <<?ut_client_tag, ProtocolTag/bytes, ?ut_register_tag, ?ut_query_tag,
    Time:32, SegmentId:16, Time:32, Padding/bytes>>;

encode (#ut_unregister_query{protocol = Protocol}) ->
  ProtocolTag = case Protocol of
    1 -> <<?ut_protocol_1_tag>>;
    2 -> <<?ut_protocol_2_tag>> end,

  <<?ut_client_tag, ProtocolTag/bytes, ?ut_unregister_tag, ?ut_query_tag,
    0:16#10/unit:8>>.

decode (<<?ut_server_tag, ?ut_protocol_1_tag,
          ?ut_register_tag, ?ut_response_tag,
          _Padding:16#12/unit:8>>) ->

  #ut_register_response{protocol    = 1,
                        server_name = nil};

decode (<<?ut_server_tag, ?ut_protocol_2_tag,
          ?ut_register_tag, ?ut_response_tag,
          _Padding:16#12/unit:8, ServerName:16#40/bytes>>) ->

  #ut_register_response{protocol    = 2,
                        server_name = unpad (ServerName)};

decode (<<?ut_server_tag, ?ut_protocol_1_tag,
          ?ut_unregister_tag, ?ut_response_tag,
          _Padding:16#12/unit:8>>) ->
  #ut_unregister_response{protocol = 1};

decode (<<?ut_server_tag, ?ut_protocol_2_tag,
          ?ut_unregister_tag, ?ut_response_tag,
          _Padding:16#12/unit:8>>) ->
  #ut_unregister_response{protocol = 2}.

% vim:set et sw=2 sts=2:
