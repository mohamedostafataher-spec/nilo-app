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

time.sleep(40)
adb('shell', 'pm', 'grant', 'eg.nilo.nilo_app', 'android.permission.RECORD_AUDIO')
adb('shell', 'monkey', '-p', 'eg.nilo.nilo_app', '-c', 'android.intent.category.LAUNCHER', '1')
time.sleep(4); shot('splash')
time.sleep(5)
shot('auth_signin')
tap_text('Create an account'); time.sleep(1); shot('auth_signup'); tap_text('Back to sign in'); time.sleep(1)
tap_text('Forgot password'); time.sleep(1); shot('auth_forgot'); tap_text('Back to sign in'); time.sleep(1)
tap_text('Continue as guest'); time.sleep(3)
for _i in range(25):
    ns = nodes()
    if any('Wait' == t.strip() for t, c, q in ns):
        tap_text('Wait'); continue
    if not any('continue as guest' in t.lower() for t, c, q in ns):
        break
    if _i % 6 == 5: tap_text('Continue as guest')
    time.sleep(3)
print('past auth', flush=True)
time.sleep(4); tap_text('Skip'); time.sleep(3); tap_text('Skip'); time.sleep(8); shot('first_run')
import subprocess
def dump(tag):
    o = subprocess.run('adb logcat -d | grep -E "FATAL|AndroidRuntime|flutter|Exception|Error" | tail -60', shell=True, capture_output=True, text=True).stdout
    open(f'{OUT}/log_{tag}.txt','w').write(o)
dump('first_run')
adb('shell','input','tap','124','1484'); time.sleep(1); adb('shell','input','tap','540','1328'); time.sleep(1); adb('shell','input','text','Traveler'); time.sleep(1); adb('shell','input','keyevent','66'); time.sleep(2); shot('first_run_filled')
adb('shell','input','tap','540','1640'); time.sleep(8); shot('home'); time.sleep(4); shot('home2')
tap_any('رسايل','Messages'); time.sleep(12); shot('tab_messages')
tap_any('حكاياتي','My stories'); time.sleep(4); shot('tab_story')
tap_any('قصص','حكاياتي','My stories'); time.sleep(4); shot('tab_stories')
tap_any('جواز','Passport'); time.sleep(4); shot('tab_passport')
tap_any('النيل','Nile'); time.sleep(3)
tap_any('ابعت بردية','Send papyrus'); time.sleep(5); shot('write_page'); tap_any('Not now') or adb('shell','input','tap','429','1398'); time.sleep(2); shot('after_gate'); tap_any('Got it'); time.sleep(1)
tap_class('EditText'); adb('shell','input','text','Hello%sfrom%sEgypt'); time.sleep(1); shot('write_typed'); hide_kb(); time.sleep(1)
tap_text('Send into the Nile'); 
for i in range(1, 6):
    time.sleep(0.8); shot('send_%d' % i)
time.sleep(6); shot('journey')
dump('after_send')
tap_any('قصص','حكاياتي','My stories'); time.sleep(5); shot('tab_stories'); tap_any('النيل','Nile'); time.sleep(2); adb('shell','input','tap','680','319'); time.sleep(3); shot('tab_Tools'); tap_text('Earth today'); time.sleep(12); shot('earth_a'); time.sleep(10); shot('earth_b'); back(); time.sleep(1); tap_text('Translation hub'); time.sleep(2); shot('hub_translate'); back(); tap_text('Travel help hub'); time.sleep(2); shot('hub_travel'); back()
for tile in ['Earth today', 'Translate', 'Phrasebook', 'Stay Safe', 'Places', 'Emergency', 'Official services', 'Floating button', 'Face to face', 'Saved']:
    if tap_text(tile):
        time.sleep(4); shot(tile.replace(' ', '_')); back(); time.sleep(1)
# Nile Bottles
if tap_text('Papyrus'):
    time.sleep(3); shot('bottles_gate')
    tap_class('EditText'); adb('shell', 'input', 'text', 'ShotBot'); hide_kb(); time.sleep(1)
    tap_text('18 or older'); time.sleep(1); shot('bottles_gate_filled')
    tap_text('Enter'); time.sleep(6); shot('papyrus_home')
    if tap_text('Send a papyrus'):
        time.sleep(2); shot('bottles_throw'); back()
    if tap_text('Catch a papyrus'):
        time.sleep(2); shot('bottles_catch')
        tap_text('Look for a papyrus'); time.sleep(5); shot('bottles_catch_result'); back()
    if tap_text('My papyri'):
        time.sleep(4); shot('bottles_inbox')
