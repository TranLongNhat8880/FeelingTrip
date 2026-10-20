"""Optional public upstream test images. No local/user images are read or uploaded."""
from pathlib import Path
from hashlib import sha256
from urllib.request import urlopen

ROOT=Path(__file__).resolve().parent.parent/'.tmp/identity-fixtures'
COMMIT='aea85c1fa14e4d52a7910af75d59ef51e62a2267'
FIXTURES={
    'image_T1.jpg':('f4455149f488f76205fdee5499ec5261d08ef6279a1cff7b778ea85405331e94',f'https://raw.githubusercontent.com/yakhyo/face-anti-spoofing/{COMMIT}/assets/image_T1.jpg'),
    'image_F1.jpg':('4b11b5d7a8a8e4a88f5f16a5426a0a7692e39e5bb45bb03b4ebe5e1606336860',f'https://raw.githubusercontent.com/yakhyo/face-anti-spoofing/{COMMIT}/assets/image_F1.jpg'),
    'image_F2.jpg':('fbbea73450ae9d9bb555c8ccac77bf39d234261fe3be4190e3ed2999690c485f',f'https://raw.githubusercontent.com/yakhyo/face-anti-spoofing/{COMMIT}/assets/image_F2.jpg'),
    'lena.jpg':('7de7ed51a1594fff247f4cae2301eceacf5313d6011e37b4a4c8733f7bb72c07','https://raw.githubusercontent.com/opencv/opencv/master/samples/data/lena.jpg'),
}
if __name__=='__main__':
    ROOT.mkdir(parents=True,exist_ok=True)
    for name,(checksum,url) in FIXTURES.items():
        path=ROOT/name
        if not path.exists():
            with urlopen(url,timeout=30) as response: data=response.read(10*1024*1024)
            if sha256(data).hexdigest()!=checksum: raise RuntimeError('Test fixture checksum mismatch')
            path.write_bytes(data)
        if sha256(path.read_bytes()).hexdigest()!=checksum: raise RuntimeError('Test fixture checksum mismatch')
    print('Public test fixtures verified in ignored .tmp directory.')
