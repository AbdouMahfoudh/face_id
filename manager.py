from kivy.uix.screenmanager import ScreenManager
import face_recognition
import json
from coder import coder, insert
import os
import sys
from functools import partial
from kivy.uix.label import Label
from kivy.uix.widget import Widget
from kivy.uix.button import Button
from kivy.uix.image import Image
from kivy.graphics import Color, Line, Rectangle
from kivy.uix.boxlayout import BoxLayout
from kivymd.uix.dialog import MDDialog
from kivymd.uix.button import MDRectangleFlatButton, MDFlatButton
import sqlite3
import threading
from kivy.clock import Clock
import time

from datetime import datetime
#import cv2 as cv
from init_cv import init_opencv
cv = init_opencv()
import pathlib
from kivy.animation import Animation

from PIL import Image as IM
from kivy.graphics import Color, RoundedRectangle

from kivy.graphics.texture import Texture
from insert import RoundedButton2
class RoundedButton2_2(Button):
    def __init__(self,background_color=(1, 1, 1, 1),source="", **kwargs):
        super().__init__(**kwargs)
        self.background_color = (0, 0, 0, 0)  # Make background transparent
        self.background_normal = ''  # Remove default background image
        self.custom_background_color = (1, 1, 1, 1)
        self.source = source
        self.font_size = 20
        self.size_hint = (None, 1)
        self.width = self.height
        self.pos_hint = {'center_x': 0.5}
        with self.canvas.before:
            Color(*self.custom_background_color)  # Set the button color
            self.rect = Rectangle(source =self.source, pos=self.pos, size=self.size, radius=[10])
        self.bind(pos=self.update_rect, size=self.update_rect)



    def update_rect(self, *args):
        self.rect.pos = self.pos
        self.rect.size = self.size

class BorderedBoxLayout(BoxLayout):
    def __init__(self, **kwargs):
        super(BorderedBoxLayout, self).__init__(**kwargs)
        self.bind(pos=self.update_border, size=self.update_border)
        with self.canvas.before:
            Color(.5, .5, .5, 1)  # Red color for the border
            self.border = Line (points=(self.x+20, self.y, self.width-20, self.y), width=2)

    def update_border(self, *args):
        self.border.points = (self.x+20, self.y, self.width-20, self.y)



class WindowManager(ScreenManager):
    dialog1 =None
    page = 'home'
    affich = 3
    def __init__(self, **kwargs):
        super(WindowManager, self).__init__(**kwargs)

    def animate (self, Screen,dure = .1, op = .5, *args):
        animation = Animation (opacity = op,duration = dure)
        animation+=Animation(opacity = 1, duration = dure)
        animation.start(Screen) 
        print("anii")
        
    def inserer_en (self, wid = None):
        if wid is not None:
            self.animate(wid)
            
        screen1 = self.get_screen("home")
        screen2 = self.get_screen("insert")
        n = screen2.ids.nom.text
        desc = screen2.ids.desc.text
        if n == "":
            self.open_dialogue("erreur d'insertion","Le champ nom est obligatoire" )
        elif '' in screen2.labels : 
            self.open_dialogue("erreur d'insertion","toutes les images sont obligatoire " )
        else :
            liste_json = []
            
            self.open_dialogue("","waiting ...")
            
            def up_ui (*args):

                    self.dialog1.dismiss()

                    for i in range(3):
                        screen2.ids[f"photo{i+1}"].clear_widgets()
                    screen2.ids.nom.text = "" 
                    screen2.ids.desc.text = ""    
                    screen2.labels = ['','','']
                    print ('done')
                    tit = f"{n} ajouter avec success"
                    self.open_dialogue(tit, "", self.tourner)
            def faile (err1,bnn):

                self.open_dialogue("erreur d'insertion",str(err1) )
                    
            def ma ():
                
                try:
                    kk = True
                    for i in range(3):
                        face_locations = face_recognition.face_locations(face_recognition.load_image_file("images/"+screen2.labels[i]))
                        #print(len(face_locations))
                        if len(face_locations) != 1 :
                            kk = False
                            Clock.schedule_once(partial(faile,f"il y'a {len(face_locations)} face dans l'image images/"+screen2.labels[i]))
                            break
                    if kk :
                        #tet = "photo_" + datetime.now().strftime("%Y%m%d_%H%M%S") +"_"
                        date = datetime.now().strftime("%Y%m%d_%H%M%S")
                        tet = "photo_" + date + "_"
                        for i in range(3):
                                
                                os.rename("images/"+screen2.labels[i], "images/"+tet+n+str(i+1)+".png" )
                                im = "images/"+tet+n+str(i+1)+".png"

                                incon_face = face_recognition.face_encodings(face_recognition.load_image_file(im))[0]
                                incon_face_list = incon_face.tolist()
                                liste_json1 = json.dumps(incon_face_list)
                                liste_json.append(liste_json1)
                       
                        sql = "insert into tst2 (name, image, image2, image3,date, description) values (?, ?, ?,?, ?, ?)"
                        param = (n,)+tuple(liste_json)+(date,desc,)
                        insert(sql, param)
                        Clock.schedule_once(up_ui)
                except Exception as e:
                    # Handle the error
                    print("Error inserting data:", e)
                    Clock.schedule_once(partial(faile,e))

                
                
            thread1 = threading.Thread(target=ma)
            thread1.start()
        
    def inserer(self, wid=None):
        if wid is not None:
            self.animate(wid)

        # Récupération des écrans
        screen1 = self.get_screen("home")
        screen2 = self.get_screen("insert")

        # Extraction des données des champs
        nom = screen2.ids.nom.text
        description = screen2.ids.desc.text

        # Validation des champs
        if not nom:
            self.open_dialogue("Erreur d'insertion", "Le champ nom est obligatoire")
            return
        elif '' in screen2.labels:
            self.open_dialogue("Erreur d'insertion", "Toutes les images sont obligatoires")
            return

        liste_json = []
        self.open_dialogue("", "En attente...")

        # Fonction de mise à jour de l'interface utilisateur
        def update_ui(*args):
            self.dialog1.dismiss()
            for i in range(3):
                screen2.ids[f"photo{i+1}"].clear_widgets()
            screen2.ids.nom.text = ""
            screen2.ids.desc.text = ""
            screen2.labels = ['', '', '']
            success_message = f"{nom} ajouté avec succès"
            self.open_dialogue(success_message, "", self.tourner)

        # Fonction en cas d'échec
        def on_failure(error_msg, *args):
            self.open_dialogue("Erreur d'insertion", str(error_msg))

        # Fonction d'insertion dans la base de données
        def insert_data():
            try:
                valid_faces = True
                # Validation des visages
                for i in range(3):
                    face_image = face_recognition.load_image_file(f"images/{screen2.labels[i]}")
                    face_locations = face_recognition.face_locations(face_image)

                    if len(face_locations) != 1:
                        valid_faces = False
                        Clock.schedule_once(partial(on_failure, f"Il y a {len(face_locations)} visage(s) dans l'image images/{screen2.labels[i]}"))
                        break

                if valid_faces:
                    # Générer un nom unique pour les images
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    prefix = f"photo_{timestamp}_{nom}"

                    for i in range(3):
                        old_image_path = f"images/{screen2.labels[i]}"
                        new_image_name = f"{prefix}{i+1}.png"
                        new_image_path = f"images/{new_image_name}"
                        
                        # Renommer et traiter l'image
                        os.rename(old_image_path, new_image_path)
                        face_encoding = face_recognition.face_encodings(face_recognition.load_image_file(new_image_path))[0]
                        face_encoding_list = face_encoding.tolist()
                        liste_json.append(json.dumps(face_encoding_list))

                    # Insertion des données dans la base
                    sql_query = "INSERT INTO tst2 (name, image, image2, image3, date, description) VALUES (?, ?, ?, ?, ?, ?)"
                    params = (nom, ) + tuple(liste_json) + (timestamp, description)
                    insert(sql_query, params)

                    # Mise à jour de l'interface après insertion
                    Clock.schedule_once(update_ui)

            except Exception as e:
                print("Erreur lors de l'insertion des données :", e)
                Clock.schedule_once(partial(on_failure, e))

        # Démarrer le traitement dans un thread séparé
        threading.Thread(target=insert_data).start()


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
    

    def add_im (self, wid = None):
        
        screen5 = self.get_screen('home')
        if screen5.running : 
            screen5.ids.camera.clear_widgets()
            screen5.close_camera()
            screen5.running = False
        self.page = 'home'
        self.current = "insert"
    def tout_en(self, par= ''):
        screen5 = self.get_screen('home')
        if screen5.running : 
            screen5.ids.camera.clear_widgets()
            screen5.close_camera()
            screen5.running = False
        screen1 = self.get_screen('tout')
        con = sqlite3.connect('Mybase.db')
        c = con.cursor()
        par = "%"+par+"%"
        c.execute(f"select id, name,date, description from tst2 where name like ? order by name limit {self.affich}", (par,) )
        records = c.fetchall()
        c.execute("select count(*) from tst2 where name like ? ",(par,)  )
        long = c.fetchone()[0]
        con.commit()
        con.close()

        screen1.bx.clear_widgets()
        if len(records) == 0:
            screen1.box[0]= Label (text = " Base de données vide ", color = (0,0,0,1), size_hint_y = None,height = 80)
            screen1.bx.add_widget(screen1.box[0])
        else : 
            screen1.box[0]= Label (text = f"il y'a {str(long)} resultats", color = (1,1,1,1), size_hint_y = None,height = 80)
            screen1.bx.add_widget(screen1.box[0])
        
        i = 0
        for record in records:
            m = Label (text = record[1] , size_hint_y = None ,height = 25, bold = True, color = (1,1,1,1))
            #m.text_size = (m.width, None)
            file = "./images/photo_" + record[2] + "_"+record[1] +str(1)+".png"
            #print(record[2])
            if os.path.exists(file):
                #print ( "file find")
                im = Image(source = file)
                im.bind(on_touch_down=partial(self.on_image_click, record[1],record[-2], record[-1]))
            else : im = Image(source = "./app_images/load.png")
            #im.size = (10,10)
            #b1 = Button (text = "Modifier" ,on_press=partial(self.modifier, str(record[0]), str(record[1])) )
            #b1 = RoundedButton2_2(background_color=(0, .8, .5, 1),source="./app_images/modifier.png", on_press=partial(self.modifier, str(record[0]), str(record[1])))
            wid = Widget(size_hint=(.8, None))
            b1 = RoundedButton2_2(source="./app_images/modifier.png", on_press=partial(self.modifier,record ))
            #b2 = Button (text = "Effacer" , on_press=partial(self.suprimer, str(record[0]), str(record[1])))
            b2 = RoundedButton2_2(source="./app_images/sup.png", on_press=partial(self.suprimer, str(record[0]), str(record[1])))
            con1 = BoxLayout(orientation="horizontal", padding=[5, 0, 10, 0])
            con1.add_widget(wid)
            
            con1.add_widget(b1)
            con2 = BoxLayout(orientation="horizontal", padding=[10, 0, 5, 0])
            con2.add_widget(b2)
            bx2 =  BoxLayout(orientation = "horizontal", size_hint_y = None ,height = 45,size_hint_x=0.8,pos_hint={'center_x': 0.5, 'center_y': 0.5})
            bx2.add_widget(con1)
            bx2.add_widget(con2)

            screen1.box[i] = BorderedBoxLayout(orientation = "vertical", size_hint_y = None ,height = 220)
                                       #'''size_hint_y = None,height = 80''')
            screen1.box[i].add_widget(m)
            screen1.box[i].add_widget(im)
            screen1.box[i].add_widget(bx2)

            screen1.bx.add_widget(screen1.box[i])
            i+=1
        
        def ghj (e):
            self.page = 'tout'
            self.current = "insert"
        
        def plus (e):
            
            self.affich *=2
            print(self.affich)
            self.tout(par)

        bbbbx = BoxLayout(orientation="vertical",spacing=20, padding=[0, 10, 0, 10], size_hint_y = None ,height = 150)
        bb1 = RoundedButton2_2(source="./app_images/plus.png",size_hint = (.5,.5), on_release = plus )
        if long <= self.affich :
            bb1.opacity = .1
            bb1.disabled = True
        bb = RoundedButton2(text= 'Ajouter un nouveau',size_hint = (.5,.5),bg=(72/255, 61/255, 139/255, 1), on_release = ghj )
        bbbbx.add_widget(bb1)
        bbbbx.add_widget(bb)
        screen1.bx.add_widget(bbbbx)
        self.current = "tout"
    
    def tout(self, search_param=''):
        # Récupérer l'écran home et s'assurer que la caméra est bien arrêtée
        home_screen = self.get_screen('home')
        if home_screen.running:
            home_screen.ids.camera.clear_widgets()
            home_screen.close_camera()
            home_screen.running = False

        # Récupérer l'écran pour l'affichage des résultats
        tout_screen = self.get_screen('tout')

        # Connexion à la base de données
        search_param = f"%{search_param}%"
        with sqlite3.connect('Mybase.db') as con:
            cursor = con.cursor()

            # Requête pour récupérer les enregistrements correspondant à la recherche
            cursor.execute(f"SELECT id, name, date, description FROM tst2 WHERE name LIKE ? ORDER BY name LIMIT {self.affich}", (search_param,))
            records = cursor.fetchall()

            # Requête pour obtenir le nombre total de résultats
            cursor.execute("SELECT COUNT(*) FROM tst2 WHERE name LIKE ?", (search_param,))
            total_count = cursor.fetchone()[0]

        # Nettoyer le conteneur de widgets
        tout_screen.bx.clear_widgets()

        # Affichage des résultats
        if not records:
            tout_screen.box[0] = Label(text="Base de données vide", color=(0, 0, 0, 1), size_hint_y=None, height=80)
            tout_screen.bx.add_widget(tout_screen.box[0])
        else:
            result_label = f"Il y a {total_count} résultats"
            tout_screen.box[0] = Label(text=result_label, color=(1, 1, 1, 1), size_hint_y=None, height=80)
            tout_screen.bx.add_widget(tout_screen.box[0])

            for i, record in enumerate(records):
                name, date, description = record[1], record[2], record[3]
                image_path = f"./images/photo_{date}_{name}1.png"

                # Créer un label pour le nom
                name_label = Label(text=name, size_hint_y=None, height=25, bold=True, color=(1, 1, 1, 1))

                # Charger l'image correspondante ou une image par défaut
                if os.path.exists(image_path):
                    image_widget = Image(source=image_path)
                    image_widget.bind(on_touch_down=partial(self.on_image_click, name, date, description))
                else:
                    image_widget = Image(source="./app_images/load.png")

                # Boutons Modifier et Supprimer
                wid = Widget(size_hint=(.1, None))
                wid2 = Widget(size_hint=(.1, None))
                modifier_button = RoundedButton2_2(source="./app_images/modifier.png", on_press=partial(self.modifier, record))
                supprimer_button = RoundedButton2_2(source="./app_images/sup.png", on_press=partial(self.suprimer, str(record[0]), str(record[1])))

                # Créer les layouts pour les boutons
                layout_buttons = BoxLayout(orientation="horizontal",spacing=20, size_hint_y=None, height=45, size_hint_x=0.8, pos_hint={'center_x': 0.5})
                layout_buttons.add_widget(wid)
                layout_buttons.add_widget(modifier_button)
                layout_buttons.add_widget(supprimer_button)
                layout_buttons.add_widget(wid2)

                # Conteneur principal pour chaque enregistrement
                tout_screen.box[i] = BorderedBoxLayout(orientation="vertical", size_hint_y=None, height=220)
                tout_screen.box[i].add_widget(name_label)
                tout_screen.box[i].add_widget(image_widget)
                tout_screen.box[i].add_widget(layout_buttons)

                # Ajouter le conteneur à l'écran
                tout_screen.bx.add_widget(tout_screen.box[i])

        # Ajouter un bouton "Plus" pour charger davantage de résultats
        def load_more_results(_):
            self.affich *= 2
            self.tout(search_param)

        load_more_button = RoundedButton2_2(source="./app_images/plus.png", size_hint=(0.5, 0.5), on_release=load_more_results)
        if total_count <= self.affich:
            load_more_button.opacity = 0.1
            load_more_button.disabled = True

        # Ajouter un bouton "Ajouter un nouveau"
        def open_insert_screen(_):
            self.page = 'tout'
            self.current = "insert"

        add_new_button = RoundedButton2(text="Ajouter un nouveau", size_hint=(0.5, 0.5), bg=(72/255, 61/255, 139/255, 1), on_release=open_insert_screen)

        # Layout final pour les boutons d'action
        action_layout = BoxLayout(orientation="vertical", spacing=20, padding=[0, 10, 0, 10], size_hint_y=None, height=150)
        action_layout.add_widget(load_more_button)
        action_layout.add_widget(add_new_button)

        # Ajouter le layout final à l'écran
        tout_screen.bx.add_widget(action_layout)

        # Mettre à jour l'écran actuel
        self.current = "tout"

    def suprimer (self, a, b, obj):
        def faite (ob):
            
            insert("delete from tst2 where id = ?", (int(a),))
            for i in range (3):
                if os.path.exists(f"./images/{b}{i+1}.png"):
                    os.remove(f"./images/{b}{i+1}.png")
                
            
            screen1 = self.get_screen("home")
            def ma (b):
                screen1.k = coder()

            th = threading.Thread(target=ma, args=("",))
            th.daemon = True
            th.start()
            self.open_dialogue(f"{b} est suprimé avec succes","",self.dismi)
        
            self.tout()

        
        self.open_dialogue(f"{b} va etre suprimé","vous etes sur ?",faite,func2=self.dismi, but2_text="Annuler")
        

    def modifier(self,record,obj):
        
        screen2 = self.get_screen("modifier1")
        screen2.ids.num.text = str(record[0])
        screen2.ids.nom.text = record[1]
        screen2.ids.desc.text = record[-1]
        screen2.labels = []
        screen2.labels2 = []
        tete = "./images/photo_"+record[2]+"_"+record[1]
        for i in range (3):
            screen2.ids[f"photo{i+1}"].clear_widgets()
            lab = Label(text = f"{record[1]}{i+1}.png")
            if os.path.exists(f"{tete}{i+1}.png"):
                im = Image(source = f"{tete}{i+1}.png", size_hint= (1, 3))
            else : im = Image(source = "./app_images/load.png", size_hint= (1, 3))
            screen2.ids[f"photo{i+1}"].add_widget(im)
            screen2.ids[f"photo{i+1}"].add_widget(lab)
            screen2.labels.append(f"{tete}{i+1}.png")
            screen2.labels2.append(f"{tete}{i+1}.png")
        print(screen2.labels2, screen2.labels)
        self.current = "modifier1"

    def modifier1(self):
        screen1 = self.get_screen("home")
        screen2 = self.get_screen("modifier1")
        id = screen2.ids.num.text
        n = screen2.ids.nom.text
        desc = screen2.ids.desc.text
        if n == "":
            self.open_dialogue("erreur de modification","Le champ nom est obligatoire" )
        elif '' in screen2.labels2 : 
            self.open_dialogue("erreur de modification","toutes les images sont obligatoire " )
        else :
            liste_json = []
            
            self.open_dialogue("","waiting ...")
            
            def up_ui (*args):

                    self.dialog1.dismiss()
                    for i in range(3):
                        screen2.ids[f"photo{i+1}"].clear_widgets()
                    screen2.labels2=[]
                    print ('done')
                    tit = f"{n} Modifié avec success"
                    self.open_dialogue(tit, "", self.tourner)
            def faile (err1,bnn):

                self.open_dialogue("erreur de modification",str(err1) )
                    
            def ma ():
                
                try:
                    kk = True
                    date = datetime.now().strftime("%Y%m%d_%H%M%S")
                    tet = "photo_" + date + "_"
                    for i in range(3):
                        face_locations = face_recognition.face_locations(face_recognition.load_image_file(screen2.labels2[i]))
                        print(len(face_locations))
                        if len(face_locations) != 1 :
                            kk = False
                            Clock.schedule_once(partial(faile,f"il y'a {len(face_locations)} face dans l'image {screen2.labels2[i]}"))
                            break
                        else :
                            if os.path.exists(screen2.labels[i]) and screen2.labels[i] != screen2.labels2[i]:
                                os.remove(screen2.labels[i])
                            os.rename(screen2.labels2[i], "./images/"+tet+n+str(i+1)+".png" )
                            im = "./images/"+tet+n+str(i+1)+".png"
                            
                            incon_face = face_recognition.face_encodings(face_recognition.load_image_file(im))[0]
                            incon_face_list = incon_face.tolist()
                            liste_json1 = json.dumps(incon_face_list)
                            liste_json.append(liste_json1)
                            print(i)
                    if kk :
                        sql = "update tst2 set name = ?, image = ?, image2 = ?, image3 = ?,date = ?, description = ? where id = ?"
                        param = (n,)+tuple(liste_json)+(date,desc,id,)
                        insert(sql, param)
                        Clock.schedule_once(up_ui)
                except Exception as e:
                    # Handle the error
                    print("Error modification data:", e)
                    Clock.schedule_once(partial(faile,e))

            thread1 = threading.Thread(target=ma)
            thread1.start()
    
    
    def modifier2(self):
        screen2 = self.get_screen("modifier")
        id = screen2.ids.num.text
        n = screen2.ids.nom.text
        self.open_dialogue("","waiting ...")
        
        def up_ui (*args):

            self.dialog1.dismiss()
            self.open_dialogue(f"{n} Modifier avec success", "", func1=self.tourner)
        
        def faile (err1,bnn):

            self.open_dialogue("erreur de modification ",str(err1))
        
        def ma () :
            try :
                if os.path.exists("images/"+n+"1.png") and n+"1.png" != screen2.ids.lab1.text:
                    os.remove("./images/"+n+"1.png")
                    #os.rename("images/"+screen2.ids.lab1.text, "images/"+n+"1.png" )
                if os.path.exists("images/"+n+"2.png") and n+"2.png" != screen2.ids.lab2.text:
                    os.remove("./images/"+n+"2.png")
                    #os.rename("images/"+screen2.ids.lab2.text, "images/"+n+"2.png" )
                if os.path.exists("images/"+n+"3.png") and n+"3.png" != screen2.ids.lab3.text:
                    os.remove("./images/"+n+"3.png")
                    #os.rename("images/"+screen2.ids.lab3.text, "images/"+n+"3.png" )
                
                params = [n]
                for i in range (3):
                    os.rename("images/"+screen2.ids[f"lab{i+1}"].text, "images/"+n+f"{i+1}.png" )
                    im = "images/"+n+f"{i+1}.png"
                    incon_face = face_recognition.face_encodings(face_recognition.load_image_file(im))[0]
                    incon_face_list = incon_face.tolist()
                    liste_json1 = json.dumps(incon_face_list)
                    params.append(liste_json1)
                params.append(id)

                params = tuple(params)
                con = sqlite3.connect('Mybase.db')
                c = con.cursor()
                c.execute("update tst2 set name = ?, image = ?, image2 = ?, image3 = ? where id = ?",params)
                con.commit()
                con.close()

                print ('done')
                Clock.schedule_once(up_ui)
                
            except Exception as e:
                print("Exeption : ", e)
                Clock.schedule_once(partial(faile,e))

        thread1 = threading.Thread(target=ma)
        thread1.start()
        
    def tourner (self, obj):
        if self.dialog1 is not None:
            self.dialog1.dismiss()
        screen1 = self.get_screen("home")
        def ma (b):
            screen1.k = coder()

        th = threading.Thread(target=ma, args=("",))
        th.daemon = True
        th.start()
        #self.current = 'tout'
        self.tout()
    def Camm1 (self, n, mode = None):
        self.mode = mode
        self.numero = n
        print('cam')
        #self.ids.camera.clear_widgets()
        screen2 = self.get_screen("camra")
        screen2.ids.annuler.opacity = .1
        screen2.ids.ajouter.opacity = .1
        if True :
            self.img = Image(source = "./app_images/load1.png")#size_hint=(None, None), size=(300, 300),pos_hint={'center_x': 0.5, 'center_y': 0.5}

            """layout = BoxLayout(orientation='vertical')
            layout.add_widget(self.img)"""
            screen2.ids.camera.clear_widgets()
            screen2.ids.camera.add_widget(self.img)


            self.cap = None
            self.event = None
            self.running = True
            #self.open_camera()
            self.current = 'camra'
            self.open_camera()
            

        else :
            screen2.ids.camera.clear_widgets()
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
            self.frr = frame
            if ret:
                
                
                #frame = cv.rotate(frame, cv.ROTATE_180)
                frame = cv.flip(frame, 1)
                #
                #gray = cv.cvtColor(frame, cv.COLOR_BGR2GRAY)
                """coordinate_list = self.pretrained_model.detectMultiScale(
                gray,
                scaleFactor=1.1,
                minNeighbors=3) """
                gray = cv.cvtColor(frame, cv.COLOR_BGR2GRAY)
                coordinate_list = self.pretrained_model.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))

                for (x,y,w,h) in coordinate_list:
                    
                    cv.rectangle(frame, (x,y), (x+w, y+h), (0,255,0), 2)
                #frame = cv.flip(frame, 0)
                
                #buf = frame.tostring()
                frame = cv.resize(frame, (300, 300))
                cv.rectangle(frame, (0,0), (frame.shape[1], frame.shape[0]), (0,0,0), 4)
                
                buf = cv.flip(frame, 0).tobytes()

                image_texture = Texture.create(size=(frame.shape[1], frame.shape[0]), colorfmt='bgr')
                image_texture.blit_buffer(buf, colorfmt='bgr', bufferfmt='ubyte')
                self.img.texture = image_texture

    def save_im1(self):  
        #im = cv.i(self.img)
        
        screen2 = self.get_screen("camra")
        print(screen2.labels)
        if screen2.labels[int(self.numero) -1] != '':
            
            tete = screen2.labels[int(self.numero) -1].split('.')[0]
            print ("tete", tete)
        else : tete = 'images/ph123'
        queu = f'{self.numero}.png'
        
                
        cv.imwrite(tete +queu, self.frr)
        #im.save("./images/eee1.png")

        self.close_camera()
        
        screen2.ids.camera.clear_widgets()
        self.img = Image(source =tete +queu)
        screen2.labels[int(self.numero) -1] = tete +queu
        #screen2.labels2[int(self.numero) -1] = tete +queu
        screen2.ids.camera.add_widget(self.img)
        screen2.ids.annuler.opacity = 1
        screen2.ids.ajouter.opacity = 1


    def annuler1 (self):
        screen3 = self.get_screen("camra")
        '''if os.path.exists(f'./images/ph{self.numero}.png'):
            os.remove(f'./images/ph{self.numero}.png')
            self.Camm1(self.numero, self.mode)'''
        #if os.path.exists(screen3.labels[int(self.numero) -1].split(".")[0][:-1] + ".png"):
        #    os.remove(screen3.labels[int(self.numero) -1].split(".")[0][:-1] + ".png")
        if os.path.exists(screen3.labels[int(self.numero) -1]):
            os.remove(screen3.labels[int(self.numero) -1])
            self.Camm1(self.numero, self.mode)
    
    def ajout1 (self):
        if self.cap == None:
            if self.mode == "ins" :
                screen3 = self.get_screen("camra")
                d = True
                i = 1
                kkk = screen3.labels[int(self.numero) -1].split(".")[0]
                while d :
                    if len(kkk) == 0:
                        d = False
                    if os.path.exists(kkk[:len(kkk) - i] + ".png"):
                        os.remove(kkk[:len(kkk) - i] + ".png")

                    if kkk[:len(kkk) - i] == 'images/ph123':
                        d=False
                    
                    i +=1
                screen2 = self.get_screen("insert")
                
                screen2.mod2(screen3.labels[int(self.numero) -1],f'photo{self.numero}',int(self.numero)-1 )
                self.current = 'insert'
            if self.mode == "mod":
                screen3 = self.get_screen("camra")
                d = True
                i = 1
                kkk = screen3.labels[int(self.numero) -1].split(".")[0]
                while d :
                    if len(kkk) == 0:
                        d = False
                    if os.path.exists(kkk[:len(kkk) - i] + ".png"):
                        os.remove(kkk[:len(kkk) - i] + ".png")

                    if kkk[:len(kkk) - i] == 'images/ph123':
                        d=False
                    
                    i +=1
                screen2 = self.get_screen("modifier1")
                screen2.mod2(screen3.labels[int(self.numero) -1],f'photo{self.numero}',int(self.numero)-1 )
                self.current = 'modifier1'
    def retour(self):
        print('retour')
        screen2 = self.get_screen("camra")
        screen2.ids.camera.clear_widgets()
        self.close_camera()
        print (self.mode)
        if self.mode == "mod":
            self.current = "modifier1"
        else : 
            self.current = "insert"
    def retour_mod (self):
        screen2 = self.get_screen("modifier1")
        for i in range(3):
            if screen2.labels[i] != screen2.labels2[i]:
                if os.path.exists('./images/'+screen2.labels2[i]):
                    os.remove('./images/'+screen2.labels2[i])
        
        self.annuler_ins()


        self.current = "tout"
        

    def annuler_ins (self, wid = None):
        if wid is not None:
            self.animate(wid)
        screen1 = self.get_screen("insert")
        screen2 = self.get_screen("camra")
        for id in ["photo1", "photo2", "photo3"] :
            screen1.ids[id].clear_widgets()
        for i in screen1.labels:
            if i != '':
                if os.path.exists(f"./images/{i}"):
                    os.remove(f"./images/{i}")
        screen1.labels = ['', '', '']
        screen1.ids["nom"].text = ""
        screen2.labels = ['', '', '']
        for file in os.listdir("./images"):
            if file[:2] == "ph123":
                os.remove("./images/"+file)

    def search (self , w=None):
        print('rchercheuu')
        screen1 = self.get_screen("tout")
        if screen1.ids.search.hint_text == "":
        
            
            screen1.ids.search.hint_text = "rechercher"
            
            self.animate(screen1.ids.search, .3, .3)
            screen1.ids.search.background_color = (.8,.8,.8, .8)

            screen1.ids.bx_search.size_hint_y = .8
            screen1.ids.but_search.size = (50,50)
        elif screen1.ids.search.text == '':
            screen1.ids.search.background_color = (.8,.8,.8, 0)
            screen1.ids.search.hint_text = ""
            screen1.ids.bx_search.size_hint_y = .2
            screen1.ids.but_search.size = (20,20)
        if screen1.ids.search.text != '':
            self.tout(screen1.ids.search.text.strip())

        
    def retour_ins(self ):
        self.current = self.page
    
    def on_key_down(self, key):
        def yy (a):
            sys.exit()
        if key == 27:  # 27 est le code pour la touche "Retour" (Escape ou Back)
            # Si on est sur la deuxième page, revenir à la première page
            if self.current == 'home':
                self.open_dialogue("vous allez quitter l'application", "vous etes sur",func1=yy, func2=self.dismi)
            
            if self.current == 'tout':
                self.current = 'home'
                
            if self.current == 'insert':
                self.retour_ins()
            if self.current == 'modifier1':
                self.retour_mod()
            if self.current == 'camra':
                self.retour()
            if self.current == 'detail':
                self.current = "tout"
            if self.current == 'image':
                self.current = "detail"
            
            return True

        return False
                
    def on_image_click(self,a,b,c, instance, touch, ):
        if instance.collide_point(*touch.pos):
            #print("Image cliquée !", a)
            # Action à effectuer lors du clic
            #self.action_on_click()
            screen2 = self.get_screen("detail")
            
            screen2.ids.nom.text = a
            screen2.ids.desc.text = c
            #screen2.ids.desc.bind(texture_size=screen2.ids.desc.setter('size'))
            #print(b)
            tete = "./images/photo_"+b+"_"+a
            for i in range (3):
                screen2.ids[f"photo{i+1}"].clear_widgets()
                #lab = Label(text = f"{a}{i+1}.png")
                if os.path.exists(f"{tete}{i+1}.png"):
                    im = Image(source = f"{tete}{i+1}.png",  allow_stretch=True, keep_ratio=True)
                    #im.size = im.texture_size 
                    im.bind(on_touch_down=partial(self.on_image_click2, f"{tete}{i+1}.png"))
                else : im = Image(source = "./app_images/load.png", size_hint= (1, 3))
                screen2.ids[f"photo{i+1}"].add_widget(im)
                #screen2.ids[f"photo{i+1}"].add_widget(lab)
                
        
            self.current = "detail"
    def on_image_click2 (self,a, instance, touch,):
        if instance.collide_point(*touch.pos):
            #print("Image cliquée !", a)
            # Action à effectuer lors du clic
            #self.action_on_click()
            screen2 = self.get_screen("image")
            screen2.ids.box.clear_widgets()
            im = Image(source = a, allow_stretch=True, keep_ratio=True)
            screen2.ids.box.add_widget(im)
            self.current = "image"