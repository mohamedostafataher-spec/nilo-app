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
    adb('shell', 'uiautomator', 'dump', '/sdcard/u.xml')
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
    for txt, c, (x, y) in nodes():
        if t.lower() in txt.lower() and (cls is None or cls in c):
            adb('shell', 'input', 'tap', str(x), str(y))
            print('tap', t, x, y, flush=True)
            return True
    print('not found', t, flush=True)
    return False
def tap_class(cls, idx=0):
    ms = [p for _, c, p in nodes() if cls in c]
    if len(ms) > idx:
        adb('shell', 'input', 'tap', str(ms[idx][0]), str(ms[idx][1]))
        return True
    return False
def back():
    adb('shell', 'input', 'keyevent', '4'); time.sleep(1.5)

adb('shell', 'pm', 'grant', 'eg.nilo.nilo_app', 'android.permission.RECORD_AUDIO')
adb('shell', 'monkey', '-p', 'eg.nilo.nilo_app', '-c', 'android.intent.category.LAUNCHER', '1')
time.sleep(4); shot('splash')
time.sleep(5)
for i in range(6):
    if tap_text('Next') or tap_text('Start'):
        time.sleep(1.2)
    if i == 0: shot('onboarding')
time.sleep(2); shot('home')
adb('shell', 'input', 'swipe', '540', '1600', '540', '600'); time.sleep(1); shot('home_scrolled')
adb('shell', 'input', 'swipe', '540', '600', '540', '1600'); time.sleep(1)
for tile in ['Translate', 'Phrasebook', 'Stay Safe', 'Places', 'Emergency', 'Official services', 'Floating button', 'Face to face', 'Saved']:
    if tap_text(tile):
        time.sleep(4); shot(tile.replace(' ', '_')); back()
# Nile Bottles
if tap_text('Nile Bottles'):
    time.sleep(3); shot('bottles_gate')
    tap_class('EditText'); adb('shell', 'input', 'text', 'ShotBot'); adb('shell', 'input', 'keyevent', '4'); time.sleep(1)
    tap_text('18 or older'); time.sleep(1); shot('bottles_gate_filled')
    tap_text('Enter'); time.sleep(6); shot('bottles_home')
    if tap_text('Throw a bottle'):
        time.sleep(2); shot('bottles_throw'); back()
    if tap_text('Catch a bottle'):
        time.sleep(2); shot('bottles_catch')
        tap_text('Look for a bottle'); time.sleep(5); shot('bottles_catch_result'); back()
    if tap_text('My bottles'):
        time.sleep(4); shot('bottles_inbox')
