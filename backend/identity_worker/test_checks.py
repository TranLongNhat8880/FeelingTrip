import itertools
import math
import unittest
from checks import Challenge, document_matches, pose_angles

class CheckTests(unittest.TestCase):
    def test_pose_yaw_uses_the_same_sign_as_mlkit_unmirrored_frames(self):
        for angle in [-30,0,30]:
            r=math.radians(angle);c=math.cos(r);s=math.sin(r)
            yaw,pitch,roll=pose_angles([[c,0,s],[0,1,0],[-s,0,c]])
            self.assertAlmostEqual(yaw,angle);self.assertAlmostEqual(pitch,0);self.assertAlmostEqual(roll,0)
    def test_document_requires_number_name_and_date(self):
        qr='001201012345||NGUYỄN VĂN TEST|15082001|Nam|Hà Nội|10112021'
        lines=['Số: 001201012345','Họ và tên: NGUYEN VAN TEST','Ngày sinh: 15/08/2001']
        self.assertTrue(document_matches(lines,qr,'001201012345'))
        for bad in ['001201012346||NGUYEN VAN TEST|15082001|Nam|Ha Noi',
                    '001201012345||NGUYEN VAN KHAC|15082001|Nam|Ha Noi',
                    '001201012345||NGUYEN VAN TEST|16082001|Nam|Ha Noi',
                    '001201012345||NGUYEN VAN TEST|31022001|Nam|Ha Noi']:
            self.assertFalse(document_matches(lines,bad,'001201012345'))
        self.assertFalse(document_matches(lines[:-1],qr,'001201012345'))

    def driver(self,challenge):
        clock=[0.]
        def frames(n,yaw=0,eye=.95):
            for _ in range(n):
                clock[0]+=.13
                challenge.frame(clock[0],yaw,0,0,eye,eye)
        return frames,clock

    def test_all_server_orders_complete_only_after_returning_to_center(self):
        for actions in itertools.permutations(['blink','turnLeft','turnRight']):
            challenge=Challenge(actions);frames,_=self.driver(challenge)
            frames(5)
            for action in actions:
                if action=='blink': frames(2);frames(2,eye=.1);frames(2)
                else: frames(4,yaw=30 if action=='turnLeft' else -30)
                self.assertFalse(challenge.complete);frames(4)
            self.assertTrue(challenge.complete)

    def test_static_photo_and_wrong_direction_cannot_pass(self):
        challenge=Challenge(['turnLeft','blink','turnRight']);frames,_=self.driver(challenge)
        frames(300);self.assertFalse(challenge.complete);self.assertEqual(challenge.step,0)
        frames(10,yaw=-35);self.assertEqual(challenge.stage,'perform')
        frames(1,yaw=35);frames(10);self.assertEqual(challenge.step,0)

    def test_invalid_challenge_gaps_and_nan_are_rejected(self):
        for bad in [[],['blink']*3,['turnLeft','turnRight','bogus']]:
            with self.assertRaises(ValueError): Challenge(bad)
        challenge=Challenge(['blink','turnLeft','turnRight']);frames,clock=self.driver(challenge)
        frames(5)
        with self.assertRaises(ValueError): challenge.frame(clock[0]+1,0,0,0,.9,.9)
        with self.assertRaises(ValueError): challenge.frame(clock[0]+.1,float('nan'),0,0,.9,.9)

if __name__=='__main__': unittest.main()
