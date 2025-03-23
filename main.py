from kivymd.app import MDApp
from kivy.lang import Builder
from manager import WindowManager
from home import Home1
from insert import Insert
from tout import Tout
from modifier1 import Modifier1
from camra import Camra
from detail import Detail
from image import Image1
import sqlite3
from kivy.core.window import Window
kv = Builder.load_file("kivy.kv")

class MyApp(MDApp):
    
    def build(self):
        con = sqlite3.connect('Mybase.db')

        c = con.cursor()

        c.execute("""
                create table if not exists tst2 ( 
                id INTEGER PRIMARY KEY,
                name TEXT,
                image TEXT,
                image2 TEXT,
                image3 TEXT,
                date text,
                description TEXT  )
            """)
        con.commit()
        con.close()
        Window.bind(on_key_down=self.on_key_down)
        return kv
    
    def on_key_down(self, window, key, *args):
        return self.root.on_key_down(key)
    
    def inserer(self):
        self.root.inserer()
    
    def tout(self):
        self.root.tout()
    
    def modifier(self):
        self.root.modifier1()
    
    
    def save_im(self):
        print('save')
        self.root.save_im1()
    def annuler(self):
        self.root.annuler1()
    def ajout(self):
        self.root.ajout1()
    

if __name__ == "__main__":
    MyApp().run()