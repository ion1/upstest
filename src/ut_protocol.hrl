-define (ut_server_port,         200).
-define (ut_discover_port,       2844).
-define (ut_monitor_port,        2845).

-define (ut_client_tag,          0, 0).
-define (ut_server_tag,          1, 0).

-define (ut_protocol_1_tag,      2, 16#10).
-define (ut_protocol_2_tag,      2, 16#20).
-define (ut_protocol_length,     2).

-define (ut_query_tag,           0).
-define (ut_response_tag,        1).

% From client.
-define (ut_register_tag,        1).
-define (ut_unregister_tag,      4).
-define (ut_am_i_there_tag,      5).
-define (ut_discover_tag,        6).

% From server.
-define (ut_shutdown_tag,        2).
-define (ut_shutdown_cancel_tag, 3).
-define (ut_get_time_tag,        7).

-record (ut_register_query,    {protocol, segment_id, time}).
-record (ut_register_response, {protocol, server_name}).

-record (ut_unregister_query,    {protocol}).
-record (ut_unregister_response, {protocol}).

% vim:set et sw=2 sts=2:
