
from kivy.core.window import Window
#import cv2 as cv
from init_cv import init_opencv
cv = init_opencv()
import face_recognition
from functools import partial
import sqlite3
import sys
from kivymd.uix.dialog import MDDialog
from kivymd.uix.button import MDRectangleFlatButton, MDFlatButton
from kivy.uix.filechooser import FileChooserListView
from kivy.uix.screenmanager import ScreenManager, Screen
import mysql.connector as MC
import json
from kivy.uix.label import Label
from kivy.uix.image import Image
import pathlib
from kivy.uix.button import Button
from kivy.animation import Animation
from tkinter import filedialog
import shutil
import os
from kivy.clock import Clock
from PIL import Image as IM

from kivy.uix.boxlayout import BoxLayout
from kivy.properties import StringProperty, ObjectProperty

class CustomBoxLayout(BoxLayout):
    label_text = StringProperty("Default Text")
    param_text = StringProperty("O")
    button_action = ObjectProperty(lambda x: print("Default Action", x))
    button_cam = ObjectProperty(lambda x: print("Default Action", x))

    def __init__(self, label_text="",param_text="1", button_action=None,button_cam=None, **kwargs):
        super().__init__(**kwargs)
        if label_text:
            self.label_text = label_text
        if param_text:
            self.param_text = param_text
        if button_action != None:
            self.button_action = button_action
        if button_cam != None:
            self.button_cam = button_cam
            pass

class RoundedButton2 (Button):
    bg = ObjectProperty((123/255, 104/255, 238/255,1))
    def __init__(self, bg=(123/255, 104/255, 238/255,1), **kwargs):
        super().__init__(**kwargs)
        if bg:
            self.bg = bg

class Insert(Screen):
    #dialog1 
    labels = ['', '', '']
    def __init__(self, **kwargs):
        super(Insert, self).__init__(**kwargs)
        self.dialog1 = None
    def animate (self, Screen, *args):
        animation = Animation (opacity = .5,duration = .1)
        animation+=Animation(opacity = 1, duration = .1)
        animation.start(Screen)    

    def Camm (self, wid) :
        pass
        
        

    def ph1(self, wid):
        self.animate(wid)
        Clock.schedule_once(lambda dt: self.mod1("photo1", 0), .2)

    def ph2(self, wid):
        self.animate(wid)
        Clock.schedule_once(lambda dt: self.mod1("photo2", 1), .2)

        
    def ph3(self, wid):
        self.animate(wid)
        Clock.schedule_once(lambda dt: self.mod1("photo3", 2), .2)

    def open_dialogue (self, tit, text , func1=None,but1_text="OK",  func2= None,but2_text="Cancel"):
        if self.dialog1 is not None:
            self.dialog1.dismiss()
        buttons = []

        if func2 is not None:
            buttons.append(MDFlatButton(text=but2_text, on_release=func2))
        if func1 is not None:
            buttons.append(MDRectangleFlatButton(text=but1_text, on_release=func1))
        
        self.dialog1 = MDDialog(
            title=tit,
            text=text,
            buttons=buttons
        )
        self.dialog1.open()

    def dismi (self, obj):
        if self.dialog1 is not None:
            self.dialog1.dismiss()
        else : pass
            
    def mod1 (self, id, i):
        def faile (err1,bnn):

                self.open_dialogue("l'image n'est pas valable ",str(err1) )
             
        self.ids[id].clear_widgets()
        file_path = filedialog.askopenfilename()
        if file_path:
            l=str(file_path).split("/")[-1]
            l = l.split(".")[0]
            l+=".png"
            #l = f"ph{i+1}.png"
            if os.path.exists("images/"+l):
                Clock.schedule_once(partial(faile,f"cette image exste deja {l} \n choisissez une autre"))
            
            else: 
                shutil.copyfile(file_path, "images/"+l)
                #self.ids.lab1.text = l
                self.resize_image("images/"+l)
                face_locations = face_recognition.face_locations(face_recognition.load_image_file("images/"+l))
                print(len(face_locations))
                kk = True
                if len(face_locations) != 1 :
                    kk = False
                    os.remove("images/"+l)
                    Clock.schedule_once(partial(faile,f"il y'a {len(face_locations)} face dans l'image {l}"))
                if kk :    
                    lab = Label(text = l)
                    im = Image(source = "./images/"+l, size_hint= (1, 3))
                    self.ids[id].add_widget(im)
                    self.ids[id].add_widget(lab)
                    #del self.labels[0]
                    if self.labels[i] != '':
                        if os.path.exists("./images/"+self.labels[i]):
                            os.remove("./images/"+self.labels[i])
                    self.labels[i] = l
                    #self.labels.append(l)
                    print(self.labels)

    def mod2 (self,file_path, id, i):
            def faile (err1,bnn):

                self.open_dialogue("l'image n'est pas valable ",str(err1) )
        
            self.ids[id].clear_widgets()
        
            l=str(file_path).split("/")[-1]
            self.resize_image("images/"+l)
            face_locations = face_recognition.face_locations(face_recognition.load_image_file("images/"+l))
            print(len(face_locations))
            kk = True
            if len(face_locations) != 1 :
                kk = False
                os.remove("images/"+l)
                Clock.schedule_once(partial(faile,f"il y'a {len(face_locations)} face dans l'image "))
            if kk : 
                lab = Label(text = l)
                im = Image(source = f"./images/{l}", size_hint= (1, 3))
                self.ids[id].add_widget(im)
                self.ids[id].add_widget(lab)
                #del self.labels[0]
                if self.labels[i] != '':
                    if os.path.exists("./images/"+self.labels[i]):
                        os.remove("./images/"+self.labels[i])
                self.labels[i] = l
                #self.labels.append(l)
                print(self.labels)


    def cam1 (self):
        #url = "http://192.168.163.205:8080/video"
        #capture = cv.VideoCapture(url) 
        print(len(self.k), "ok")
        capture = cv.VideoCapture(0, cv.CAP_DSHOW) #to open Camera
        '''cas = pathlib.Path(cv.__file__).parent.absolute() / "data/haarcascade_frontalface_default.xml"
        if getattr(sys, 'frozen', False):  # Vérifie si l'application est exécutée à partir d'un exécutable PyInstaller
            cas = "cv2/data/haarcascade_frontalface_default.xml"'''

    
        #pretrained_model = cv.CascadeClassifier(str(cas))
        d=True
        while d:
            boolean, frame = capture.read()
            gray = cv.cvtColor(frame, cv.COLOR_BGR2GRAY)
            #coordinate_list = pretrained_model.detectMultiScale(
            gray,
            if cv.waitKey(20) == ord('x'):
                    break
            
            if cv.waitKey(20) == ord('x'):
                break        
            # Display detected face
            cv.imshow("Live Face Detection", frame)
        capture.release()
        cv.destroyAllWindows()


    def annuler (self):

        for id in ["photo1", "photo2", "photo3"] :
            self.ids[id].clear_widgets()
        for i in self.labels:
            if i != '':
                os.remove(f"./images/{i}")
        self.labels = ['', '', '']
        self.ids["nom"].text = ""

    def resize_image(self, image_path, size=(128, 128)):
        image = IM.open(image_path)
        print(image.size[0],image.size[1] )
        if image.size[0] > size[0] :
            image = image.resize((size[0],image.size[1] ))
        if image.size[1] > size[1] :
            image = image.resize((image.size[0] ,size[1]))
        #image = image.resize(size)
        image.save(image_path)
        print(image.size[0],image.size[1] )