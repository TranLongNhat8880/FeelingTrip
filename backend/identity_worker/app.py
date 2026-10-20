import hmac
import json
import logging
import os
import threading
from pathlib import Path
from dotenv import load_dotenv

from flask import Flask, jsonify, request
from engine import Engine

load_dotenv(Path(__file__).resolve().parent/'.env')
app=Flask(__name__)
app.config['MAX_CONTENT_LENGTH']=36*1024*1024
key=os.environ.get('EKYC_WORKER_KEY','')
if len(key)<32: raise RuntimeError('Set EKYC_WORKER_KEY to 32+ random characters before starting the worker')
logging.getLogger('werkzeug').setLevel(logging.WARNING)
engine=Engine()
capacity=threading.BoundedSemaphore(1)

@app.before_request
def authenticate():
    if not hmac.compare_digest(request.headers.get('X-Worker-Key',''),key):
        return jsonify(error='Unauthorized'),401

@app.get('/health')
def health(): return jsonify(ready=True,model='SFace-2021dec')

@app.post('/verify')
def verify():
    if not capacity.acquire(blocking=False): return jsonify(error='Busy'),429
    try:
        actions=json.loads(request.form.get('actions','null'))
        if not isinstance(actions,list) or len(actions)!=3 or set(actions)!={'blink','turnLeft','turnRight'}:
            return jsonify(error='Invalid challenge'),400
        files={}
        for field in ['cccdFrontImage','cccdBackImage','selfieImage','livenessVideo']:
            if field not in request.files: return jsonify(error='Missing evidence'),400
            data=request.files[field].read((20 if field=='livenessVideo' else 5)*1024*1024+1)
            if not data or len(data)>(20 if field=='livenessVideo' else 5)*1024*1024:
                return jsonify(error='Invalid evidence size'),400
            files[field]=data
        result=engine.verify(files,request.form.get('cccdNumber',''),request.form.get('qrData',''),actions)
        return jsonify(result)
    except Exception:
        # Do not log documents, request bodies, file paths, or biometric vectors.
        return jsonify(error='Identity processing failed'),503
    finally: capacity.release()

if __name__=='__main__':
    from waitress import serve
    serve(app,host=os.environ.get('HOST','127.0.0.1'),port=int(os.environ.get('PORT','5101')),threads=4,
          max_request_body_size=36*1024*1024,channel_timeout=120)
