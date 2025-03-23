
from kivy.core.window import Window
#import cv2 as cv
from init_cv import init_opencv
cv = init_opencv()
import face_recognition
import sqlite3
import numpy as np
from kivy.uix.screenmanager import ScreenManager, Screen
import json
import sys
import pathlib
from kivy.animation import Animation
import threading
from coder import coder
from kivy.clock import Clock
from kivy.uix.image import Image
from kivy.uix.boxlayout import BoxLayout
from kivy.graphics.texture import Texture

from kivy.graphics import Color, Line
class Home1(Screen):
    
    def __init__(self, **kwargs):
        super(Home1, self).__init__(**kwargs)
        self.k = []
        self.running = False
        print('klkl')
        def ma (b):
            
            self.k = coder()
            #pass

        th = threading.Thread(target=ma, args=("",))
        th.daemon = True
        th.start()


    def animate (self, Screen, *args):
        animation = Animation (opacity = .5,duration = .1)
        animation+=Animation(opacity = 1, duration = .1)
        animation.start(Screen)
    def cam_encien(self, frame):
        
        small_frame = cv.resize(frame, (0, 0), fx=0.25, fy=0.25)
        rgb_small_frame = cv.cvtColor(small_frame, cv.COLOR_BGR2RGB)
        face_locations = face_recognition.face_locations(rgb_small_frame)
        info =[]
        if len(face_locations)>0:
            for location in face_locations:
                face_encoding = np.array(face_recognition.face_encodings(rgb_small_frame, [location]))
                
                for i in range(len(self.k)):
                    l=[]
                    for j in range(3):
                        l1 = face_recognition.compare_faces([self.k[i][j+1]], face_encoding , tolerance=0.45)
                        l.append(l1[0])
                    """l2 = face_recognition.compare_faces([k[i][2]], face_encoding , tolerance=0.6)
                    l3 = face_recognition.compare_faces([k[i][3]], face_encoding , tolerance=0.6)
                    l = [l1[0], l2[0], l3[0]]"""
                    if True in l:
                        info.append([location, self.k[i][0]])
                        break
                       
                
        return info 
        
    
    def cam2(self, frame):
        # Réduction de la taille de l'image et conversion en RGB
        small_frame = cv.resize(frame, (0, 0), fx=0.25, fy=0.25)
        rgb_small_frame = cv.cvtColor(small_frame, cv.COLOR_BGR2RGB)

        # Détection des visages
        face_locations = face_recognition.face_locations(rgb_small_frame)
        info = []

        if face_locations:
            for location in face_locations:
                # Encodage du visage détecté
                face_encoding = np.array(face_recognition.face_encodings(rgb_small_frame, [location]))

                # Comparaison avec les visages stockés
                for person in self.k:
                    matches = []
                    
                    # Comparer l'encodage du visage avec ceux stockés
                    for face_index in range(1, 4):  # on itère sur les trois encodages stockés
                        match = face_recognition.compare_faces([person[face_index]], face_encoding, tolerance=0.45)
                        matches.append(match[0])
                    
                    # Si une correspondance est trouvée
                    if any(matches):
                        info.append([location, person[0]])
                        break  # Sortir de la boucle après la première correspondance

        return info


    def cam3 (self):
        #self.ids.camera.clear_widgets()
        if not self.running :
            self.img = Image(source = "./app_images/load1.png")#size_hint=(None, None), size=(300, 300),pos_hint={'center_x': 0.5, 'center_y': 0.5}
            
            """layout = BoxLayout(orientation='vertical')
            layout.add_widget(self.img)"""
            self.ids.camera.add_widget(self.img)


            self.cap = None
            self.event = None
            self.running = True
            self.open_camera()

        else :
            self.ids.camera.clear_widgets()
            self.close_camera()
            self.running = False

    def open_camera(self):
        if self.cap is None:
            self.cap = cv.VideoCapture(0, cv.CAP_DSHOW)
            #capture = cv.VideoCapture(0, cv.CAP_DSHOW) #to open Camera
            self.cas = pathlib.Path(cv.__file__).parent.absolute() / "data/haarcascade_frontalface_default.xml"
            if getattr(sys, 'frozen', False):  # Vérifie si l'application est exécutée à partir d'un exécutable PyInstaller
                self.cas = "cv2/data/haarcascade_frontalface_default.xml"
            #self.pretrained_model = cv.CascadeClassifier(str(self.cas))
            self.pretrained_model = cv.CascadeClassifier(cv.data.haarcascades + 'haarcascade_frontalface_default.xml')

            self.event = Clock.schedule_interval(self.update, 1.0 / 30)
            
        

    def close_camera(self):
        if self.cap is not None:
            self.cap.release()
            self.cap = None
            self.event.cancel()
            self.img.texture = None

    def update(self, dt):
        if self.cap is not None:
            ret, frame = self.cap.read()

            if ret:
                frame = cv.flip(frame, 1)
                gray = cv.cvtColor(frame, cv.COLOR_BGR2GRAY)
                coordinate_list = self.pretrained_model.detectMultiScale(
                gray,
                scaleFactor=1.1,
                minNeighbors=3) 
                if len (self.k) > 0:
                    infos = self.cam2(frame)
                    
                else : infos = []
                name = "inconnu"
                num =0
                nombre = len(coordinate_list)
                for (x,y,w,h) in coordinate_list:
                    #print(coordinate_list)
                    if num < len(infos) and nombre ==1:
                        name = infos[num][1]
                        cv.putText(frame, name, (x,y-10), cv.FONT_HERSHEY_DUPLEX, 1, (255, 0, 0), 1)
                        cv.rectangle(frame, (x,y), (x+w, y+h), (0,255,0), 2)
                        
                        num+=1   
                    if len(infos)==0 and nombre ==1:
                        cv.putText(frame, name, (x,y-10), cv.FONT_HERSHEY_DUPLEX, 1, (255, 0, 0), 1)
                        cv.rectangle(frame, (x,y), (x+w, y+h), (0,255,0), 2)
                        
                        

                    if nombre > 1 : 
                        cv.putText(frame, "plusieurs faces", (30,40), cv.FONT_HERSHEY_DUPLEX, 1, (0, 0, 255), 1)
                        cv.rectangle(frame, (x,y), (x+w, y+h), (0,255,0), 2)
                        
                #frame = cv.rotate(frame, cv.ROTATE_180)
                frame = cv.resize(frame, (300, 300))
                
                cv.rectangle(frame, (0,0), (frame.shape[1], frame.shape[0]), (0,0,0), 4)
                
                buf = cv.flip(frame, 0).tostring()
                image_texture = Texture.create(size=(frame.shape[1], frame.shape[0]), colorfmt='bgr')
                image_texture.blit_buffer(buf, colorfmt='bgr', bufferfmt='ubyte')
                self.img.texture = image_texture