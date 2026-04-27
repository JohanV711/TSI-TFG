from fastapi import FastAPI 


app= FastAPI()

#Ruta raiz
@app.get("/")
def hola_mundo():
    return{
        "msg":"Hola mundo"
    }