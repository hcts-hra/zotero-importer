xquery version "3.0";

declare default element namespace "http://www.loc.gov/mods/v3";

declare namespace zapi="http://zotero.org/ns/api";
declare namespace atom="http://www.w3.org/2005/Atom";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace z="http://www.zotero.org/namespaces/export#";
declare namespace dc="http://purl.org/dc/elements/1.1/";
declare namespace dcterms="http://purl.org/dc/terms/";

import module namespace functx="http://www.functx.com";

declare function local:rec-get-items($uri as xs:anyURI, $api-key as xs:string) {
    let $body := httpclient:get(xs:anyURI($uri || "&amp;key=" || $api-key) , true(), ())/httpclient:body/*
    let $self := $body/atom:link[@rel="self"]/@href/string()
    let $next := $body/atom:link[@rel="next"]/@href/string()
    let $last := $body/atom:link[@rel="last"]/@href/string()
    let $entries := $body/atom:entry

    return
        if (not($next) or $self = $last) then
            $body/atom:entry
        else
            (
                $entries,
                local:rec-get-items(xs:anyURI($next), $api-key)
            )
};

let $api-key := ""
let $init-uri := xs:anyURI("https://api.zotero.org/users/475425/collections/9KH9TNSJ/items/top?format=atom&amp;content=mods&amp;limit=100&amp;itemType=-attachment")
let $target-collection := xmldb:encode-uri("/data/temp/testimport")

let $clear-target-collection := true()
let $simulate := true()
let $limit-entries := false()

(: empty target collection if not simulating? :)
let $cleanup :=
    if(not($simulate) and $clear-target-collection) then
        (
        if (xmldb:collection-available($target-collection)) then 
            xmldb:remove($target-collection)
        else
            ()
        ,        
        xmldb:create-collection(functx:substring-before-last($target-collection, "/"), functx:substring-after-last($target-collection, "/"))
        )
    else
        ()

(: get all data :)
let $entries := local:rec-get-items($init-uri, $api-key)


(: process only $limit entries:)
let $entries :=
    if ($limit-entries) then
        $entries[position() < $limit-entries]
    else
        $entries
return
    <div>
    {
        for $entry in $entries
        return 
                let $zotero-url := data($entry/atom:id)
                let $zotero-id := $entry/zapi:key/string()
                (: get children:)
            (:    let $children :=:)
            (:        if($entry//zapi:numChildren > 0) then:)
            (:            let $children-call := xs:anyURI($group-uri || "/items/" || $zotero-id || "/children?key=" || $api-key || "&amp;format=atom&amp;content=rdf_zotero"):)
            (:            let $children-response := httpclient:get($children-call, true(), ())//httpclient:body:)
            (:            return:)
            (:                <children>:)
            (:                    <call>{$children-call}</call>:)
            (:                    {:)
            (:                        for $child in $children-response//atom:entry/atom:content:)
            (:                            return:)
            (:                                <child itemType="{$child/z:itemType/string()}">:)
            (:                                    <title>{$child//dc:title/string()}</title>:)
            (:                                    <value>{$child//dc:identifier/dcterms:URI/rdf:value/string()}</value>:)
            (:                                </child>:)
            (:                    }:)
            (:                </children>:)
            (:        else :)
            (:            <children/>:)
            
                
                let $uuid := "uuid-" || util:uuid($zotero-url)
                let $filename := $uuid || ".xml"
                let $mods-cleanedup := functx:change-element-ns-deep($entry//mods, "http://www.loc.gov/mods/v3", "")
                return
                    if ($simulate) then
                        <entry>
                            <zotero-id>{$zotero-id}</zotero-id>
                            <numChildren>{data($entry//zapi:numChildren)}</numChildren>
                            <children>{()}</children>
                            <uuid>{$uuid}</uuid>
                            <entry>{$entry}</entry>
                            <data>{$entry}</data>
                            <store>{$mods-cleanedup}</store>
                        </entry>
                    else
                        let $doc-uri := xmldb:store($target-collection, $filename, $mods-cleanedup)
                        let $doc := doc($doc-uri) 
                        let $update-id-attribute := update insert attribute ID{$uuid} into $doc/mods
                        let $update-copyright-date := update rename $doc//copyrightDate as 'dateIssued'
                        return
                            <document>{$doc-uri}</document>
    }
    </div>