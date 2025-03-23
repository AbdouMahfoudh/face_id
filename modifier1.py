
from kivy.uix.screenmanager import ScreenManager, Screen

from tkinter import filedialog
import shutil
import os
from kivy.clock import Clock
from PIL import Image as IM

from kivymd.uix.dialog import MDDialog
from kivymd.uix.button import MDRectangleFlatButton, MDFlatButton
import face_recognition
from functools import partial
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.image import Image
from kivy.uix.boxlayout import BoxLayout
from kivy.properties import StringProperty, ObjectProperty

from kivy.animation import Animation
class Custom1BoxLayout(BoxLayout):
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

        
class Modifier1 (Screen):
    labels = []
    labels2 = []
    dialog1 = None
    def animate (self, Screen, *args):
        animation = Animation (opacity = .5,duration = .1)
        animation+=Animation(opacity = 1, duration = .1)
        animation.start(Screen)    

    def ph1(self, wid):
        self.animate(wid)
        #self.mod1("photo1", 0)
        Clock.schedule_once(lambda dt: self.mod1("photo1", 0), .2)

    
    def ph2(self, wid):
        #self.mod1("photo2", 1)
        self.animate(wid)
        #self.mod1("photo1", 0)
        Clock.schedule_once(lambda dt: self.mod1("photo2", 1), .2)

        
    def ph3(self, wid):
        #self.mod1("photo3", 2)
        self.animate(wid)
        #self.mod1("photo1", 0)
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
    
    def mod1(self, a, i):
        def faile (err1,bnn):

                self.open_dialogue("l'image n'est pas valable ",str(err1) )
        
        file_path = filedialog.askopenfilename()
        if file_path:
            
            l=str(file_path).split("/")[-1]
            l = l.split(".")[0]
            l+=".png"
            if os.path.exists("images/"+l):
                Clock.schedule_once(partial(faile,f"cette image exste deja {l} \n choisissez une autre"))
            
            else :
                shutil.copyfile(file_path, "images/"+l)
                #self.ids.lab1.text = l
                self.resize_image("images/"+l)
                face_locations = face_recognition.face_locations(face_recognition.load_image_file("images/"+l))
                print(len(face_locations))
                kk = True
                if len(face_locations) != 1 :
                    kk = False
                    os.remove("images/"+l)
                    Clock.schedule_once(partial(faile,f"il y'a {len(face_locations)} face dans l'image "))
                if kk :
                    self.ids[a].clear_widgets()
                    lab = Label(text = l)
                    im = Image(source = "./images/"+l, size_hint= (1, 3))
                    self.ids[a].add_widget(im)
                    self.ids[a].add_widget(lab)
                    if self.labels2[i] != self.labels[i]:
                        if os.path.exists(self.labels2[i]):
                            os.remove(self.labels2[i])
                    self.labels2[i] = "./images/"+l
                    #self.labels.append(l)
                    print(self.labels, "\n", self.labels2)

    def mod2(self,file_path, a, i):
            def faile (err1,bnn):

                self.open_dialogue("l'image n'est pas valable ",str(err1) )
        
            l=str(file_path).split("/")[-1]
            lab = Label(text = l)
            self.resize_image("images/"+l)
            face_locations = face_recognition.face_locations(face_recognition.load_image_file("images/"+l))
            print(len(face_locations))
            kk = True
            if len(face_locations) != 1 :
                kk = False
                os.remove("images/"+l)
                Clock.schedule_once(partial(faile,f"il y'a {len(face_locations)} face dans l'image "))
            if kk :
                self.ids[a].clear_widgets()
            
                im = Image(source = "./images/"+l, size_hint= (1, 3))
                self.ids[a].add_widget(im)
                self.ids[a].add_widget(lab)

                if self.labels2[i] != '':
                    if os.path.exists(self.labels2[i]):
                        if self.labels2[i] != self.labels[i]:
                            os.remove(self.labels2[i])
                self.labels2[i] = "./images/"+l
                #self.labels.append(l)
                print(self.labels2)
            

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