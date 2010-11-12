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

-record (ut_am_i_there_query,    {protocol, ipv4_addr}).
-record (ut_am_i_there_response, {protocol, status}).

-record (ut_discover_query,    {protocol, each_segment}).
-record (ut_discover_response, {protocol, server_ipv4_addr, server_name,
                                have_multip_segs, segment_id, segment_name,
                                unknown_a=nil, unknown_4c=nil}).

-record (ut_shutdown_query,    {protocol, client_id,
                                unknown_6=nil, unknown_8=nil, unknown_12=nil}).
-record (ut_shutdown_response, {protocol, shutdown_delay,
                                unknown_6=nil, unknown_a=nil}).

-record (ut_shutdown_cancel_query,    {protocol, unknown_6=nil}).
-record (ut_shutdown_cancel_response, {protocol}).

-record (ut_get_time_query,    {protocol, unknown_6=nil}).
-record (ut_get_time_response, {protocol, time}).

% vim:set et sw=2 sts=2:
