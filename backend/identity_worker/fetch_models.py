"""Download public model weights only. Never upload user documents or images."""
import hashlib
from pathlib import Path
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent / 'models'
COMMIT = '47534e27c9851bb1128ccc0102f1145e27f23f98'
MODELS = {
    'ocr-det.onnx': (
        'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.10.0/onnx/PP-OCRv4/det/ch_PP-OCRv4_det_mobile.onnx',
        'd2a7720d45a54257208b1e13e36a8479894cb74155a5efe29462512d42f49da9'),
    'ocr-cls.onnx': (
        'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.10.0/onnx/PP-OCRv4/cls/ch_ppocr_mobile_v2.0_cls_mobile.onnx',
        'e47acedf663230f8863ff1ab0e64dd2d82b838fceb5957146dab185a89d6215c'),
    'ocr-rec.onnx': (
        'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.10.0/onnx/PP-OCRv5/rec/latin_PP-OCRv5_rec_mobile.onnx',
        'b20bd37c168a570f583afbc8cd7925603890efbcdc000a59e22c269d160b5f5a'),
    'minifasnet-v2.onnx': (
        'https://github.com/yakhyo/face-anti-spoofing/releases/download/weights/MiniFASNetV2.onnx',
        'b32929adc2d9c34b9486f8c4c7bc97c1b69bc0ea9befefc380e4faae4e463907'),
    'yunet.onnx': (
        f'https://media.githubusercontent.com/media/opencv/opencv_zoo/{COMMIT}/models/face_detection_yunet/face_detection_yunet_2023mar.onnx',
        '8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4'),
    'sface.onnx': (
        f'https://media.githubusercontent.com/media/opencv/opencv_zoo/{COMMIT}/models/face_recognition_sface/face_recognition_sface_2021dec.onnx',
        '0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79'),
    'face_landmarker.task': (
        'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task',
        '64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff'),
}

def download():
    ROOT.mkdir(exist_ok=True)
    for name, (url, expected) in MODELS.items():
        target = ROOT / name
        if not target.exists():
            with urlopen(url, timeout=120) as response:
                data = response.read(60 * 1024 * 1024)
            if len(data) < 100000:
                raise RuntimeError(f'Model download incomplete: {name}')
            if expected and hashlib.sha256(data).hexdigest() != expected:
                raise RuntimeError(f'Model checksum mismatch: {name}')
            target.write_bytes(data)
        actual = hashlib.sha256(target.read_bytes()).hexdigest()
        if expected and actual != expected:
            raise RuntimeError(f'Model checksum mismatch: {name}')
        print(f'{name}: sha256={actual}', flush=True)

if __name__ == '__main__':
    download()
