"""Real model checks against optional, public upstream fixtures (never personal CCCD)."""
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import cv2
from PIL import Image, ImageDraw, ImageFont, ImageOps

from engine import Engine, CheckFailed

FIXTURES=Path(__file__).resolve().parent.parent/'.tmp/identity-fixtures'

@unittest.skipUnless(all((FIXTURES/name).exists() for name in ['image_T1.jpg','image_F1.jpg','image_F2.jpg','lena.jpg']),'Public model fixtures not installed')
class EngineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.engine=Engine()

    def test_real_model_same_and_different_faces(self):
        engine=self.engine
        genuine=cv2.imread(str(FIXTURES/'image_T1.jpg'));other=cv2.imread(str(FIXTURES/'lena.jpg'))
        a=engine.feature(genuine);b=engine.feature(other)
        self.assertGreater(engine.similarity(a,a),.99)
        with self.assertRaises(CheckFailed) as error: engine.similarity(a,b)
        self.assertEqual(error.exception.code,'FACE_MISMATCH')

    def test_pad_rejects_both_public_spoof_examples(self):
        engine=self.engine
        for name in ['image_F1.jpg','image_F2.jpg']:
            image=cv2.imread(str(FIXTURES/name));h,w=image.shape[:2]
            engine.detector.setInputSize((w,h));_,faces=engine.detector.detect(image);box=faces[0]
            with self.assertRaises(CheckFailed) as error:
                engine.anti_spoof(image,box[0]/w,box[1]/h,(box[0]+box[2])/w,(box[1]+box[3])/h)
            self.assertEqual(error.exception.code,'LIVENESS_FAILED')

    def test_real_ocr_and_qr_detect_test_document(self):
        number='001201012345';qr=number+'||NGUYEN VAN TEST|15082001|Nam|Ha Noi|10112021'
        document=Image.new('RGB',(1280,800),'white');draw=ImageDraw.Draw(document)
        try: font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',34)
        except OSError: font=ImageFont.load_default(size=34)
        draw.text((450,180),'CAN CUOC CONG DAN',font=font,fill='black')
        draw.text((450,260),'So: '+number,font=font,fill='black')
        draw.text((450,340),'Ho va ten: NGUYEN VAN TEST',font=font,fill='black')
        draw.text((450,420),'Ngay sinh: 15/08/2001',font=font,fill='black')
        photo=ImageOps.exif_transpose(Image.open(FIXTURES/'image_T1.jpg')).resize((330,440));document.paste(photo,(30,100))
        code=cv2.QRCodeEncoder_create().encode(qr)
        code=cv2.copyMakeBorder(code,4,4,4,4,cv2.BORDER_CONSTANT,value=255)
        document.paste(Image.fromarray(code).resize((250,250),resample=Image.Resampling.NEAREST),(950,500))
        output=io.BytesIO();document.save(output,format='PNG');encoded=output.getvalue()
        files={'cccdFrontImage':encoded,'cccdBackImage':encoded,
               'selfieImage':(FIXTURES/'image_T1.jpg').read_bytes(),'livenessVideo':b'invalid'}
        # Only the video analyzer is isolated here. QR, OCR, face detection,
        # embeddings and the public-image comparison execute real model inference.
        with patch.object(self.engine,'video',return_value=([.8,.8],[.99,.99])):
            result=self.engine.verify(files,number,qr,['blink','turnLeft','turnRight'])
        self.assertTrue(result['verified'],result.get('code'))
        wrong=self.engine.verify(files,number,qr.replace('NGUYEN VAN TEST','NGUYEN VAN KHAC'),['blink','turnLeft','turnRight'])
        self.assertFalse(wrong['verified']);self.assertEqual(wrong['code'],'DOCUMENT_MISMATCH')

    def test_static_video_cannot_complete_liveness_and_temp_is_cleaned(self):
        image=cv2.imread(str(FIXTURES/'image_T1.jpg'));h,w=image.shape[:2]
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'static.mp4'
            writer=cv2.VideoWriter(str(path),cv2.VideoWriter_fourcc(*'mp4v'),25,(w,h))
            for _ in range(150): writer.write(image)
            writer.release();data=path.read_bytes()
        feature=self.engine.feature(image)
        before=set(Path(tempfile.gettempdir()).glob('feelingtrip-identity-*'))
        with self.assertRaises(CheckFailed) as error:
            self.engine.video(data,['blink','turnLeft','turnRight'],feature,feature)
        self.assertEqual(error.exception.code,'LIVENESS_FAILED')
        self.assertEqual(before,set(Path(tempfile.gettempdir()).glob('feelingtrip-identity-*')))

if __name__=='__main__': unittest.main()
