import subprocess, time, re, os, xml.etree.ElementTree as ET
OUT = 'shots'
os.makedirs(OUT, exist_ok=True)
n = [0]
def adb(*a, **k):
    return subprocess.run(['adb'] + list(a), capture_output=True, text=True, **k).stdout
def shot(name):
    n[0] += 1
    f = f'{OUT}/{n[0]:02d}_{name}.png'
    with open(f, 'wb') as fh:
        fh.write(subprocess.run(['adb', 'exec-out', 'screencap', '-p'], capture_output=True).stdout)
    print('shot', f, flush=True)
def nodes():
    adb('shell', 'rm', '-f', '/sdcard/u.xml'); adb('shell', 'uiautomator', 'dump', '/sdcard/u.xml')
    x = adb('shell', 'cat', '/sdcard/u.xml')
    try:
        root = ET.fromstring(x[x.index('<'):])
    except Exception:
        return []
    out = []
    for e in root.iter('node'):
        b = re.findall(r'\d+', e.get('bounds', ''))
        if len(b) == 4:
            b = list(map(int, b))
            out.append((e.get('text', '') + ' ' + e.get('content-desc', ''), e.get('class', ''), ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)))
    return out
def tap_text(t, cls=None):
    ns = nodes()
    for txt, c, (x, y) in ns:
        if 'Wait' == txt.strip():
            adb('shell', 'input', 'tap', str(x), str(y)); print('dismissed ANR', flush=True); time.sleep(2); ns = nodes(); break
    for txt, c, (x, y) in ns:
        if t.lower() in txt.lower() and (cls is None or cls in c):
            adb('shell', 'input', 'tap', str(x), str(y))
            print('tap', t, x, y, flush=True)
            return True
    print('not found', t, flush=True)
    return False
def tap_any(*ls):
    for l in ls:
        if tap_text(l): return True
    return False

def tap_class(cls, idx=0):
    ms = [p for _, c, p in nodes() if cls in c]
    if len(ms) > idx:
        adb('shell', 'input', 'tap', str(ms[idx][0]), str(ms[idx][1]))
        return True
    return False
def kb_shown():
    return 'mInputShown=true' in adb('shell', 'dumpsys', 'input_method')
def focus_ok():
    return 'eg.nilo' in adb('shell', 'dumpsys', 'window')[:0] or 'eg.nilo' in subprocess.run('adb shell dumpsys window | grep mCurrentFocus', shell=True, capture_output=True, text=True).stdout
def back():
    adb('shell', 'input', 'keyevent', '4'); time.sleep(1.5)
    if not focus_ok():
        adb('shell', 'monkey', '-p', 'eg.nilo.nilo_app', '-c', 'android.intent.category.LAUNCHER', '1'); time.sleep(5)
def hide_kb():
    time.sleep(1.5)
    if kb_shown():
        adb('shell', 'input', 'keyevent', '4'); time.sleep(1.5)


def dumptxt(tag):
    t = [x[0].strip() for x in nodes() if x[0].strip()]
    open(f'{OUT}/txt_{tag}.txt', 'w').write('\n'.join(t))
def step(name):
    shot(name); dumptxt(name)
def anr():
    for txt, c, (x, y) in nodes():
        if txt.strip() == 'Wait':
            adb('shell', 'input', 'tap', str(x), str(y)); time.sleep(2); return
def size():
    m = re.search(r'(\d+)x(\d+)', adb('shell', 'wm', 'size'))
    return int(m.group(1)), int(m.group(2))
W, H = size()
print('screen', W, H, flush=True)
time.sleep(40)
adb('shell', 'settings', 'put', 'system', 'font_scale', '1.0')
adb('shell', 'monkey', '-p', 'eg.nilo.nilo_app', '-c', 'android.intent.category.LAUNCHER', '1')
time.sleep(10); anr(); step('onboarding_translate')
tap_text('Skip'); time.sleep(4); anr(); step('entry')
def T(x, y, w=3):
    adb('shell', 'input', 'tap', str(x), str(y)); time.sleep(w)
T(540, 1232, 1); adb('shell', 'input', 'text', 'Traveler'); time.sleep(1); adb('shell', 'input', 'keyevent', '4'); time.sleep(1.5)
T(124, 1388, 1); step('entry_filled')
T(540, 1544, 8); step('after_guest')
time.sleep(6); step('home')
for _ in range(3):
    T(540, 2000, 1) if False else None
for i in range(5):
    T(int(W * (i + 0.5) / 5), 2170, 6); step('nav%d' % i)
dump('final')
