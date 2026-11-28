import json,sys,time,urllib.request,urllib.parse
UA='Nilo-pipeline/1.0 (github.com/mohamedostafataher-spec)'
def api(**kw):
    kw['format']='json'
    r=urllib.request.Request('https://en.wikipedia.org/w/api.php?'+urllib.parse.urlencode(kw),headers={'User-Agent':UA})
    return json.load(urllib.request.urlopen(r,timeout=30))
def cat(title):
    out={}
    cont={}
    while True:
        d=api(action='query',generator='categorymembers',gcmtitle='Category:'+title,gcmlimit=500,gcmtype='page',prop='coordinates|pageprops|info',colimit=500,ppprop='wikibase_item',inprop='',**cont)
        for pid,p in d.get('query',{}).get('pages',{}).items():
            c=p.get('coordinates',[{}])[0]
            if 'lat' in c: out[p['title']]=dict(name=p['title'],lat=c['lat'],lon=c['lon'],qid=p.get('pageprops',{}).get('wikibase_item',''),cat=title)
        if 'continue' in d: cont=d['continue']
        else: break
        time.sleep(0.3)
    return out
if __name__=='__main__':
    allp={}
    for t in sys.argv[2:]:
        r=cat(t); print(t,len(r)); allp.update(r); time.sleep(0.5)
    json.dump(list(allp.values()),open(sys.argv[1],'w'),ensure_ascii=False)
    print(len(allp))
