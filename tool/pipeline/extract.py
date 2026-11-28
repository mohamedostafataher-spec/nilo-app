import osmium, json, math, sys, time
PLACES = json.load(open(sys.argv[2]))   # [{id,name,lat,lon,r}]
R = 6371000.0
def box(p):
    dlat = p['r'] / 111320.0
    dlon = p['r'] / (111320.0 * math.cos(math.radians(p['lat'])))
    return (p['lat']-dlat, p['lat']+dlat, p['lon']-dlon, p['lon']+dlon)
GRID = {}
for p in PLACES:
    p['b'] = box(p); p['out'] = {'b': [], 'h': [], 'w': [], 'g': []}
    b = p['b']
    for i in range(int(b[0]*100)-1, int(b[1]*100)+2):
        for j in range(int(b[2]*100)-1, int(b[3]*100)+2):
            GRID.setdefault((i, j), []).append(p)
def local(p, lat, lon):
    return (round((lon-p['lon'])*111320.0*math.cos(math.radians(p['lat']))), round((lat-p['lat'])*111320.0))
def hgt(t):
    h = t.get('height')
    try:
        if h: return float(h.replace('m','').strip())
    except: pass
    lv = t.get('building:levels')
    try:
        if lv: return float(lv) * 3.2
    except: pass
    return 0.0
t0 = time.time(); n = 0
KEYS = ('building','highway','natural','waterway','leisure')
class H(osmium.SimpleHandler):
    def way(self, w):
        global n
        tg = w.tags
        if not any(k in tg for k in KEYS): return
        n += 1
        try:
            pts = [(nd.lat, nd.lon) for nd in w.nodes]
        except osmium.InvalidLocationError:
            return
        if len(pts) < 2: return
        la, lo = pts[0]
        for p in GRID.get((int(la*100), int(lo*100)), ()):
            b = p['b']
            if not (b[0] <= la <= b[1] and b[2] <= lo <= b[3]): continue
            pl = [local(p, a, c) for a, c in pts]
            if 'building' in tg and len(pl) >= 4:
                p['out']['b'].append({'p': pl, 'h': hgt(tg), 'k': tg.get('building'), 'n': tg.get('name','')})
            elif 'highway' in tg and tg['highway'] in ('primary','secondary','tertiary','residential','pedestrian','footway','service','unclassified','living_street','cycleway','path'):
                p['out']['h'].append({'p': pl, 'k': tg['highway']})
            elif tg.get('natural') == 'water' or tg.get('waterway') in ('river','canal','riverbank'):
                p['out']['w'].append({'p': pl, 'k': tg.get('waterway', 'water')})
            elif tg.get('leisure') in ('park','garden','pitch','playground') or tg.get('natural') in ('wood',):
                p['out']['g'].append({'p': pl, 'k': tg.get('leisure') or tg.get('natural')})
H().apply_file(sys.argv[1], locations=True, idx='sparse_file_array,/tmp/nodes.idx')
RW = {'primary':10,'secondary':8,'tertiary':7,'residential':6,'unclassified':6,'service':4,'pedestrian':5,'footway':2.5,'path':2,'cycleway':2.5,'living_street':5}
import os
os.makedirs('packs', exist_ok=True)
def conv(pl): return [[x, -y] for x, y in pl]
for p in PLACES:
    o = p['out']
    bl = []
    for x in o['b']:
        pts = x['p']
        if pts[0] == pts[-1]: pts = pts[:-1]
        if len(pts) < 3: continue
        h = x['h'] if x['h'] > 0 else 9.0
        bl.append({'h': max(3, min(300, round(h, 1))), 'p': conv(pts)})
    rd = [{'w': RW.get(x['k'], 4), 'p': conv(x['p'])} for x in o['h']]
    wt = []
    for x in o['w']:
        pts = x['p']
        if pts[0] == pts[-1] and len(pts) >= 4: wt.append(conv(pts[:-1]))
        elif x['k'] in ('river', 'canal'): rd.append({'w': 14 if x['k']=='river' else 8, 'c': 'w', 'p': conv(pts)})
    gr = [conv(x['p'][:-1]) for x in o['g'] if x['p'][0] == x['p'][-1] and len(x['p']) >= 4]
    out = {'b': bl[:1800], 'r': rd[:1500], 'w': wt, 'g': gr}
    json.dump(out, open(f"packs/{p['id']}.json", 'w'), separators=(',', ':'))
    print(p['id'], p['name'], len(bl), len(rd), len(wt), len(gr))
print('ways scanned', n, 'secs', round(time.time()-t0))
