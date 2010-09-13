%%%----------------------------------------------------------------------
%%%  mod_httpsrgapi.erl - provide http api for shared roster group management
%%%  Copyright (C) 2010  bhuztez <bhuztez@gmail.com>
%%%
%%% This program is free software: you can redistribute it and/or modify
%%% it under the terms of the GNU General Public License as published by
%%% the Free Software Foundation, either version 3 of the License, or
%%% (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%% GNU General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program.  If not, see <http://www.gnu.org/licenses/>.
%%%
%%%----------------------------------------------------------------------

-module(mod_httpsrgapi).
-author('bhuztez@gmail.com').

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("mod_roster.hrl").
-include("web/ejabberd_http.hrl").
-include("web/ejabberd_web_admin.hrl").

-behaviour(gen_mod).

-export([start/2, stop/1, process/2]).


%%%----------------------------------------------------------------------
%%% REQUEST HANDLERS
%%%----------------------------------------------------------------------


process(["srg-list", Host], _Request) ->
  SRGroups = mod_shared_roster:list_groups(Host),
  html_response([?XE("ul", lists:map(
       fun(Group) ->
            ?XE("li", [?C(Group)])
        end, SRGroups))]);

process(["srg-create-group", Host, Group], _Request) ->
   mod_shared_roster:create_group(Host, Group),
   html_response([?C("OK")]);

process(["srg-delete-group", Host, Group], _Request) ->
   mod_shared_roster:delete_group(Host, Group),
   html_response([?C("OK")]);

%% XXX
process(["srg-add-displayed-group", Host, Group, DisplayGroup], _Request) ->
   GroupOpts = mod_shared_roster:get_group_opts(Host, Group),
   case GroupOpts of
       error ->
           {404, [], {xmlelement, "h1", [], [{xmlcdata, "404 Not Found"}]}};
       Opts ->
           DisplayedGroups = get_opt(Opts, displayed_groups, []),

           case lists:member(DisplayGroup, DisplayedGroups) of
               true ->
                   html_response([?C("already exists")]);
               false ->
                   NewDisplayedGroups = DisplayedGroups ++ [DisplayGroup],
                   replace_displayed_groups(Host, Group, Opts, DisplayedGroups, NewDisplayedGroups),
                   html_response([?C("OK")])
           end
   end;

%% XXX
process(["srg-remove-displayed-group", Host, Group, DisplayGroup], _Request) ->
   GroupOpts = mod_shared_roster:get_group_opts(Host, Group),
   case GroupOpts of
       error ->
           {404, [], {xmlelement, "h1", [], [{xmlcdata, "404 Not Found"}]}};
       Opts ->
           DisplayedGroups = get_opt(Opts, displayed_groups, []),
           NewDisplayedGroups = lists:delete(DisplayGroup, DisplayedGroups),
           replace_displayed_groups(Host, Group, Opts, DisplayedGroups, NewDisplayedGroups),
           html_response([?C("OK")])
   end;



process(["srg-add-user", Host, Group, User], _Request) ->
   mod_shared_roster:add_user_to_group(Host, {User, Host}, Group),
   html_response([?C("OK")]);

process(["srg-add-user", Host, Group, User, Server], _Request) ->
   mod_shared_roster:add_user_to_group(Host, {User, Server}, Group),
   html_response([?C("OK")]);

process(["srg-remove-user", Host, Group, User], _Request) ->
   mod_shared_roster:remove_user_from_group(Host, {User, Host}, Group),
   html_response([?C("OK")]);

process(["srg-remove-user", Host, Group, User, Server], _Request) ->
   mod_shared_roster:remove_user_from_group(Host, {User, Server}, Group),
   html_response([?C("OK")]);


               
process(["list-user-resources", Host, User], _Request) ->
  Resources = ejabberd_sm:get_user_resources(User, Host),
  html_response([?XE("ul", lists:map(
       fun(R) ->
            ?XE("li", [?C(R)])
        end, Resources))]);

process(["is-user-online", Host, User, Resource], _Request) ->
  case ejabberd_sm:get_user_info(User, Host, Resource) of
    offline ->
        html_response([?C("OFFLINE")]);
    Info when is_list(Info) ->
        html_response([?C("ONLINE")]);
    _ ->
      {404, [], {xmlelement, "h1", [], [{xmlcdata, "404 Not Found"}]}}
  end;


process(_LocalPath, _Request) ->
  {404, [], {xmlelement, "h1", [], [{xmlcdata, "404 Not Found"}]}}.

%%%----------------------------------------------------------------------
%%% BEHAVIOUR CALLBACKS
%%%----------------------------------------------------------------------

start(_Host, _Opts) ->
  ok.

stop(_Host) ->
  ok.


%%%----------------------------------------------------------------------
%%% UTILITIES
%%%----------------------------------------------------------------------

get_opt(Opts, Opt, Default) ->
   case lists:keysearch(Opt, 1, Opts) of
       {value, {_, Val}} ->
           Val;
       false ->
           Default
   end.


html_response(Content) ->
    ?XE("html", [
        ?XE("body", Content)
    ]).


replace_displayed_groups(Host, Group, Opts, Old, New)->
    NewOpts = lists:delete(
        {displayed_groups, Old},
        Opts) ++ [{displayed_groups, New}],
    mod_shared_roster:set_group_opts(Host, Group, NewOpts).


