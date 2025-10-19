-module(feed_parser_ffi).
-export([parse_feed/1]).
-include_lib("xmerl/include/xmerl.hrl"). 

parse_feed(XmlBinary) ->
    try
        XmlString = binary_to_list(XmlBinary),
        {Doc, _} = xmerl_scan:string(XmlString, [{quiet, true}]),
        
        % Try RSS first, then Atom
        case parse_rss(Doc) of
            {ok, Feed} -> {ok, Feed};
            error -> parse_atom(Doc)
        end
    catch
        _:_ -> {error, <<"Failed to parse XML">>}
    end.

parse_rss(Doc) ->
    try
        % Get channel info
        [Channel] = xmerl_xpath:string("//channel", Doc),
        Title = extract_text(Channel, "title"),
        Description = extract_text_opt(Channel, "description"),
        
        % Get items
        Items = xmerl_xpath:string("//item", Doc),
        Posts = [parse_rss_item(Item) || Item <- Items],
        
        {ok, {parsed_feed, 
              unicode:characters_to_binary(Title), 
              Description,
              Posts}}
    catch
        _:_ -> error
    end.

parse_rss_item(Item) ->
    Guid = extract_text_or_link(Item, "guid", "link"),
    Title = extract_text(Item, "title"),
    Link = extract_text(Item, "link"),
    Description = extract_text_opt(Item, "description"),
    Content = extract_text_opt(Item, "content:encoded"),
    PubDate = extract_text_opt(Item, "pubDate"),
    
    {parsed_post,
     unicode:characters_to_binary(Guid),
     unicode:characters_to_binary(Title),
     unicode:characters_to_binary(Link),
     Description,
     Content,
     PubDate}.

parse_atom(Doc) ->
    try
        % Get feed info
        [Feed] = xmerl_xpath:string("//feed", Doc),
        Title = extract_text(Feed, "title"),
        Description = extract_text_opt(Feed, "subtitle"),
        
        % Get entries
        Entries = xmerl_xpath:string("//entry", Doc),
        Posts = [parse_atom_entry(Entry) || Entry <- Entries],
        
        {ok, {parsed_feed,
              unicode:characters_to_binary(Title),
              Description,
              Posts}}
    catch
        Type:Reason:Stack ->
            io:format("parse_atom error: ~p:~p~nStack: ~p~n", [Type, Reason, Stack]),
            {error, <<"Not a valid RSS or Atom feed">>}
    end.

parse_atom_entry(Entry) ->
    Id = extract_text(Entry, "id"),
    Title = extract_text(Entry, "title"),
    Link = extract_atom_link(Entry),
    Summary = extract_text_opt(Entry, "summary"),
    Content = extract_text_opt(Entry, "content"),
    Published = extract_text_opt_with_fallback(Entry, "published", "updated"),
    
    {parsed_post,
     unicode:characters_to_binary(Id),
     unicode:characters_to_binary(Title),
     unicode:characters_to_binary(Link),
     Summary,
     Content,
     Published}.

extract_text(Node, Path) ->
    case xmerl_xpath:string("./" ++ Path ++ "/text()", Node) of
        [#xmlText{value=Text}|_] -> Text;
        [] -> ""
    end.

extract_text_opt(Node, Path) ->
    case extract_text(Node, Path) of
        "" -> none;
        Text -> {some, unicode:characters_to_binary(Text)}
    end.

extract_text_opt_with_fallback(Node, Path1, Path2) ->
    case extract_text(Node, Path1) of
        "" -> extract_text_opt(Node, Path2);
        Text -> {some, unicode:characters_to_binary(Text)}
    end.

extract_text_or_link(Node, Path1, Path2) ->
    case extract_text(Node, Path1) of
        "" -> extract_text(Node, Path2);
        Text -> Text
    end.

extract_atom_link(Node) ->
    case xmerl_xpath:string("./link[@rel='alternate']/@href", Node) of
        [#xmlAttribute{value=Href}|_] -> Href;
        [] ->
            case xmerl_xpath:string("./link/@href", Node) of
                [#xmlAttribute{value=Href}|_] -> Href;
                [] -> ""
            end
    end.
