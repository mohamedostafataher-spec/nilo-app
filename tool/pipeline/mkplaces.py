import json,math,sys,re
rows=json.load(open(sys.argv[1]))['results']['bindings']
seen={}
for b in rows:
    q=b['s']['value'].split('/')[-1]
    if q in seen: continue
    m=re.match(r'Point\(([-0-9.]+) ([-0-9.]+)\)',b['loc']['value'])
    lon,lat=float(m.group(1)),float(m.group(2))
    seen[q]=dict(qid=q,name=b['l']['value'],sl=int(b['sl']['value']),lat=lat,lon=lon,type=b.get('t',{}).get('value',''))
pl=sorted(seen.values(),key=lambda p:-p['sl'])
keep=[]
for p in pl:
    if any(abs(p['lat']-k['lat'])<0.0011 and abs(p['lon']-k['lon'])<0.0016 for k in keep): continue
    keep.append(p)
for p in keep:
    p['id']='%.3f_%.3f'%(p['lat'],p['lon']); p['r']=350
json.dump(keep,open(sys.argv[2],'w'),ensure_ascii=False)
print(len(seen),'->',len(keep),'places after merging near duplicates')
