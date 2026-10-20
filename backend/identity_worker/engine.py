import io
import math
import tempfile
import os
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps
from rapidocr import RapidOCR, LangRec, OCRVersion, ModelType
from mediapipe.tasks.python import BaseOptions
from mediapipe.tasks.python.vision import FaceLandmarker, FaceLandmarkerOptions, RunningMode

from checks import Challenge, document_matches, normalize, pose_angles

ROOT = Path(__file__).resolve().parent / 'models'
os.environ['OPENCV_FFMPEG_CAPTURE_OPTIONS']='protocol_whitelist;file'
MIN_SIMILARITY = .50

class CheckFailed(Exception):
    def __init__(self, code): self.code = code

class Engine:
    def __init__(self):
        cv2.setNumThreads(2)
        self.detector = cv2.FaceDetectorYN.create(str(ROOT/'yunet.onnx'), '', (320,320), .85, .3, 5000)
        self.recognizer = cv2.FaceRecognizerSF.create(str(ROOT/'sface.onnx'), '')
        options=ort.SessionOptions(); options.intra_op_num_threads=2
        self.pad=ort.InferenceSession(str(ROOT/'minifasnet-v2.onnx'),sess_options=options,providers=['CPUExecutionProvider'])
        self.ocr = RapidOCR(params={
            'Rec.lang_type': LangRec.LATIN,
            'Rec.ocr_version': OCRVersion.PPOCRV5,
            'Rec.model_type': ModelType.MOBILE,
            'Rec.model_path': str(ROOT/'ocr-rec.onnx'),
            'Det.model_path': str(ROOT/'ocr-det.onnx'),
            'Cls.model_path': str(ROOT/'ocr-cls.onnx'),
            'Global.log_level': 'error',
            'Det.ocr_version': OCRVersion.PPOCRV4,
            'Det.model_type': ModelType.MOBILE,
            'EngineConfig.onnxruntime.intra_op_num_threads': 2,
            'EngineConfig.onnxruntime.inter_op_num_threads': 1,
        })
        # Download/load OCR weights at startup, never during a user's first request.
        self.ocr._load_det_model()
        self.ocr._load_cls_model()
        self.ocr._load_rec_model()

    @staticmethod
    def image(data, card=False):
        try:
            with Image.open(io.BytesIO(data)) as source:
                if source.width*source.height>10000000 or min(source.size)<240 or max(source.size)<480:
                    raise CheckFailed('IMAGE_QUALITY')
                source.load()
                image=np.asarray(ImageOps.exif_transpose(source).convert('RGB'))[:,:,::-1].copy()
        except CheckFailed: raise
        except Exception: raise CheckFailed('IMAGE_QUALITY')
        if max(image.shape[:2])>1600:
            image=cv2.resize(image,None,fx=1600/max(image.shape[:2]),fy=1600/max(image.shape[:2]))
        return image

    def feature(self,image):
        self.detector.setInputSize((image.shape[1],image.shape[0]))
        _, faces=self.detector.detect(image)
        if faces is None or len(faces)!=1 or min(faces[0][2:4])<20:
            raise CheckFailed('IMAGE_QUALITY')
        aligned=self.recognizer.alignCrop(image,faces[0])
        result=self.recognizer.feature(aligned).copy()
        if not np.isfinite(result).all(): raise CheckFailed('IMAGE_QUALITY')
        return result

    def similarity(self,a,b):
        score=float(self.recognizer.match(a,b,cv2.FaceRecognizerSF_FR_COSINE))
        if not math.isfinite(score) or score<MIN_SIMILARITY: raise CheckFailed('FACE_MISMATCH')
        return min(score,1.)

    @staticmethod
    def qr(image):
        detector=cv2.QRCodeDetector()
        for scale in [1., .75, 1.5]:
            resized=cv2.resize(image,None,fx=scale,fy=scale) if scale!=1 else image
            value,_,_=detector.detectAndDecode(resized)
            if value and '|' in value: return value.strip()
        return None

    def verify(self,files,number,qr,actions):
        result={'verified':False,'documentMatched':False,'faceMatched':False,'livenessPassed':False,
                'model':'SFace-2021dec','faceScores':[],'cccdNumber':number}
        try:
            front=self.image(files['cccdFrontImage'],True)
            back=self.image(files['cccdBackImage'],True)
            selfie=self.image(files['selfieImage'])
            card_feature=self.feature(front)
            selfie_feature=self.feature(selfie)
            result['faceScores'].append(self.similarity(card_feature,selfie_feature))
            actual_qr=self.qr(front) or self.qr(back)
            if actual_qr is None: raise CheckFailed('DOCUMENT_MISMATCH')
            actual_parts=actual_qr.split('|'); expected_parts=qr.split('|')
            if len(actual_parts)<6 or len(expected_parts)<6 or any(
                normalize(actual_parts[i])!=normalize(expected_parts[i]) for i in [0,2,3]):
                raise CheckFailed('DOCUMENT_MISMATCH')
            output=self.ocr(front)
            texts=output.txts if output.txts is not None else []
            confidences=output.scores if output.scores is not None else []
            lines=[str(text) for text,score in zip(texts,confidences) if float(score)>=.80]
            if not document_matches(lines,actual_qr,number): raise CheckFailed('DOCUMENT_MISMATCH')
            result['documentMatched']=True
            video_scores,pad_scores=self.video(files['livenessVideo'],actions,card_feature,selfie_feature)
            result['faceScores'].extend(video_scores)
            result.update(verified=True,faceMatched=True,livenessPassed=True,code='VERIFIED',padPassed=True,padScores=pad_scores)
        except CheckFailed as failure:
            result['code']=failure.code
        return result

    def video(self,data,actions,card_feature,selfie_feature):
        if len(data)<16 or data[4:8]!=b'ftyp': raise CheckFailed('LIVENESS_FAILED')
        challenge=Challenge(actions)
        scores=[];pad_scores=[]
        # OS temporary directory is removed on every exit, including model failures.
        with tempfile.TemporaryDirectory(prefix='feelingtrip-identity-') as directory:
            path=Path(directory)/'capture.mp4'; path.write_bytes(data)
            video=cv2.VideoCapture(str(path),cv2.CAP_FFMPEG)
            options=FaceLandmarkerOptions(base_options=BaseOptions(model_asset_path=str(ROOT/'face_landmarker.task')),
                running_mode=RunningMode.VIDEO,num_faces=2,output_face_blendshapes=True,
                output_facial_transformation_matrixes=True,min_face_detection_confidence=.7,min_face_presence_confidence=.7)
            try:
                fps=video.get(cv2.CAP_PROP_FPS); count=video.get(cv2.CAP_PROP_FRAME_COUNT)
                width=video.get(cv2.CAP_PROP_FRAME_WIDTH); height=video.get(cv2.CAP_PROP_FRAME_HEIGHT)
                if not (10<=fps<=60 and 4<=count/fps<=50 and 240<=min(width,height) and max(width,height)<=1920):
                    raise CheckFailed('LIVENESS_FAILED')
                stride=max(1,round(fps/8)); index=0; last_identity=-10; seen=False
                with FaceLandmarker.create_from_options(options) as landmarker:
                    while True:
                        okay,frame=video.read()
                        if not okay: break
                        index+=1
                        if index%stride: continue
                        now=index/fps
                        if now>48: raise CheckFailed('LIVENESS_FAILED')
                        image=mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(frame,cv2.COLOR_BGR2RGB))
                        detected=landmarker.detect_for_video(image,round(now*1000))
                        if len(detected.face_landmarks)!=1:
                            if not seen and not detected.face_landmarks and now<8: continue
                            raise CheckFailed('LIVENESS_FAILED')
                        seen=True
                        points=detected.face_landmarks[0]
                        xs=[p.x for p in points];ys=[p.y for p in points]
                        if min(xs)<0 or max(xs)>1 or min(ys)<0 or max(ys)>1 or max(xs)-min(xs)<.2:
                            raise CheckFailed('LIVENESS_FAILED')
                        matrix=np.asarray(detected.facial_transformation_matrixes[0])[:3,:3]
                        yaw,pitch,roll=pose_angles(matrix)
                        blend={c.category_name:c.score for c in detected.face_blendshapes[0]}
                        left=1-blend.get('eyeBlinkLeft',1);right=1-blend.get('eyeBlinkRight',1)
                        try: challenge.frame(now,yaw,pitch,roll,left,right)
                        except ValueError: raise CheckFailed('LIVENESS_FAILED')
                        if abs(yaw)<15 and abs(pitch)<18 and now-last_identity>=.5:
                            feature=self.feature(frame)
                            self.similarity(selfie_feature,feature)
                            scores.append(self.similarity(card_feature,feature));last_identity=now
                            pad_scores.append(self.anti_spoof(frame,min(xs),min(ys),max(xs),max(ys)))
                        if challenge.complete: break
                if not challenge.complete or len(scores)<2 or len(pad_scores)<2: raise CheckFailed('LIVENESS_FAILED')
                return scores,pad_scores
            finally: video.release()

    def anti_spoof(self,image,left,top,right,bottom):
        height,width=image.shape[:2]
        center=np.array([(left+right)*width/2,(top+bottom)*height/2])
        box=np.array([(right-left)*width,(bottom-top)*height])
        factor=min(2.7,(width-1)/box[0],(height-1)/box[1])
        start=np.maximum(0,np.floor(center-box*factor/2)).astype(int)
        end=np.minimum([width-1,height-1],np.ceil(center+box*factor/2)).astype(int)
        crop=image[start[1]:end[1]+1,start[0]:end[0]+1]
        if crop.size==0: raise CheckFailed('LIVENESS_FAILED')
        tensor=cv2.resize(crop,(80,80)).astype(np.float32).transpose(2,0,1)[None]
        logits=self.pad.run(None,{self.pad.get_inputs()[0].name:tensor})[0]
        probs=np.exp(logits-logits.max());probs=probs/probs.sum()
        live=float(probs.reshape(-1)[1])
        if not math.isfinite(live) or live<.90: raise CheckFailed('LIVENESS_FAILED')
        return live
