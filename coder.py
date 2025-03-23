
import json
import sqlite3
import os
def coder1 ():
    try:
        con = sqlite3.connect('Mybase.db')
        c = con.cursor()
        c.execute("select * from tst2")
        result = c.fetchall()
        con.commit()
        con.close()
        if result:
            # La colonne liste_data contient la liste sous forme de chaîne JSON
            #print(len(result))
            list = []
            for i in range (len(result)):
                lll=[]
                #print(result[0])
                lll.append(result[i][1])
                for j in range (2,len(result[i]) -2):
                    liste_json = result[i][j]
                    ma_list = json.loads(liste_json)
                    lll.append(ma_list)
                list.append(lll)
                #print(len(list[0][0]))
                #print(list[0])
            k = list
            print ('codé', "kll")
            hh =[]
            for file in os.listdir("./images"):
                for i in range (len(result)):
                    if file[:len(file)-5] == "photo_"+result[i][5]+"_"+result[i][1]: #k[i][0]:
                        hh.append(file)
            #print(hh)
            for file in os.listdir("./images"):
                if file not in hh:
                    os.remove("./images/"+file)
                        
            return k
        
        return []
        
                
    except Exception as e:
        print(e)
        return []



def coder():
    try:
        # Connexion à la base de données
        with sqlite3.connect('Mybase.db') as con:
            c = con.cursor()
            c.execute("SELECT * FROM tst2")
            result = c.fetchall()

        if not result:
            return []

        processed_data = []
        
        # Traitement des résultats de la requête
        for row in result:
            temp_list = [row[1]]  # Ajout du premier élément (index 1)
            for json_data in row[2:-2]:  # Traiter les colonnes JSON
                temp_list.append(json.loads(json_data))
            processed_data.append(temp_list)

        print('Codé', "kll")

        # Liste des fichiers dans le dossier "images"
        valid_files = []
        for row in result:
            for file in os.listdir("./images"):
                # Comparaison des noms de fichiers avec les données de la BDD
                expected_name = f"photo_{row[5]}_{row[1]}"
                if file.startswith(expected_name):
                    valid_files.append(file)

        # Supprimer les fichiers non correspondants
        for file in os.listdir("./images"):
            if file not in valid_files:
                os.remove(os.path.join("./images", file))

        return processed_data

    except sqlite3.Error as db_error:
        print(f"Erreur SQLite : {db_error}")
        return []
    except (json.JSONDecodeError, OSError) as error:
        print(f"Erreur : {error}")
        return []
    except Exception as e:
        print(f"Erreur inconnue : {e}")
        return []



def insert (sql, par=None):
    con = sqlite3.connect('Mybase.db')

    c = con.cursor()
    if par is not None :
        c.execute(sql,par)
    else : c.execute(sql)
    c.close()
    con.commit()
    con.close()