-module (upstest_app).

-behaviour (application).

%% Application callbacks
-export ([start/2, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

start (_StartType, _StartArgs) ->
  upstest_sup:start_link ().

stop (_State) ->
  ok.

% vim:set et sw=2 sts=2:
