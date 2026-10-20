"""Deterministic policy checks. Biometric scores are model similarities, not percentages."""
import datetime
import math
import re
import unicodedata

def pose_angles(matrix):
    # Canonical face +Z points toward the camera. Positive yaw turns toward
    # the right side of the unmirrored image, matching ML Kit's Euler Y.
    return (
        math.degrees(math.atan2(matrix[0][2],matrix[2][2])),
        math.degrees(math.atan2(matrix[1][2],math.hypot(matrix[0][2],matrix[2][2]))),
        math.degrees(math.atan2(matrix[1][0],matrix[1][1])),
    )

def normalize(text):
    text = unicodedata.normalize('NFD', text.upper().replace('Đ', 'D'))
    return re.sub(r'[^A-Z0-9]+', ' ', ''.join(c for c in text if not unicodedata.combining(c))).strip()

def document_matches(lines, qr, number):
    parts = qr.strip().split('|')
    if len(parts) < 6 or parts[0].strip() != number or not re.fullmatch(r'\d{12}', number):
        return False
    name = normalize(parts[2])
    if len(name.split()) < 2 or len(name) < 4:
        return False
    try:
        dob = datetime.datetime.strptime(parts[3].strip(), '%d%m%Y').date()
        if not datetime.date(1900, 1, 1) <= dob <= datetime.date.today():
            return False
    except ValueError:
        return False
    normalized = ' '.join(normalize(line) for line in lines)
    number_found = any(re.search(r'(?<!\d)'+re.escape(number)+r'(?!\d)',re.sub(r'\s','',line)) for line in lines)
    name_found = f' {name} ' in f' {normalized} '
    dates = set()
    for line in lines:
        for d, m, y in re.findall(r'(?<!\d)(\d{1,2})\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{4})(?!\d)', line):
            try: dates.add(datetime.date(int(y), int(m), int(d)))
            except ValueError: pass
    return number_found and name_found and dob in dates

class Challenge:
    def __init__(self, actions):
        if len(actions) != 3 or set(actions) != {'blink', 'turnLeft', 'turnRight'}:
            raise ValueError('Invalid server challenge')
        self.actions = actions
        self.step = 0
        self.stage = 'align'
        self.blink = 0
        self.hold_start = None
        self.hold_frames = 0
        self.closed_at = None
        self.previous = None

    @property
    def complete(self): return self.stage == 'complete'

    def clear(self):
        self.hold_start = None
        self.hold_frames = 0

    def hold(self, condition, now, seconds, frames=2):
        if not condition:
            self.clear()
            return False
        if self.hold_start is None: self.hold_start = now
        self.hold_frames += 1
        return now - self.hold_start >= seconds and self.hold_frames >= frames

    def frame(self, now, yaw, pitch, roll, left, right):
        if self.complete: return
        if not all(math.isfinite(x) for x in [now, yaw, pitch, roll, left, right]):
            raise ValueError('Invalid measurements')
        if self.previous is not None and (now <= self.previous or now-self.previous > .8):
            raise ValueError('Interrupted video')
        self.previous = now
        straight = abs(yaw) <= 15 and abs(pitch) <= 18 and abs(roll) <= 18
        opened = left >= .60 and right >= .60
        if self.stage == 'align':
            if self.hold(straight and opened,now,.4,3):
                self.stage = 'perform'; self.clear()
            return
        if self.stage == 'center':
            if self.hold(straight and opened,now,.25,2):
                self.step += 1; self.blink = 0; self.closed_at = None; self.clear()
                self.stage = 'complete' if self.step == 3 else 'perform'
            return
        action = self.actions[self.step]
        if action != 'blink':
            turned = yaw >= 20 if action == 'turnLeft' else yaw <= -20
            if self.hold(turned and abs(pitch)<=25 and abs(roll)<=25,now,.25,2):
                self.stage = 'center'; self.clear()
        elif not straight:
            self.blink = 0; self.closed_at = None; self.clear()
        elif self.blink == 0:
            if self.hold(opened,now,.10): self.blink = 1; self.clear()
        elif self.blink == 1:
            if left <= .40 and right <= .40:
                if self.closed_at is None: self.closed_at = now
                if self.hold(True,now,.07): self.blink = 2; self.clear()
            else: self.closed_at = None; self.clear()
        elif now-self.closed_at > 1.7:
            self.blink = 0; self.closed_at = None; self.clear()
        elif self.hold(opened,now,.10): self.stage = 'center'; self.clear()
