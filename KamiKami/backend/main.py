import firebase_admin
from firebase_admin import credentials, firestore
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import mercadopago
import uvicorn
import os
import json

app = FastAPI()

# 1. Configuração de CORS (Essencial para Flutter Web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 2. Inicializar Firebase de forma segura
# Se o arquivo JSON não estiver na raiz, o servidor avisará no log
try:
    nome_arquivo_json = "kamikami-af5fe-firebase-adminsdk-fbsvc-f14d81f29a.json"
    if not firebase_admin._apps:
        cred = credentials.Certificate(nome_arquivo_json)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase conectado com sucesso!")
except Exception as e:
    print(f"❌ Erro ao iniciar Firebase: {e}")

# 3. Configurar Mercado Pago
sdk = mercadopago.SDK("APP_USR-819053197713657-011222-74cd3d9202216f9f85ec2c1cbb5e50f2-181707904QUI")

# --- ROTA DE REGISTRO ---
@app.post('/registrar_usuario')
async def registrar_usuario(request: Request):
    try:
        dados = await request.json()
        telefone = str(dados.get('telefone', '')).strip()
        
        if not telefone:
            return {"status": "erro", "mensagem": "Telefone é obrigatório"}

        user_ref = db.collection('usuarios').document(telefone)
        if user_ref.get().exists:
            return {"status": "erro", "mensagem": "Este telefone já está cadastrado!"}
        
        user_data = {
            "nome": dados.get('nome'),
            "telefone": telefone,
            "senha": str(dados.get('senha')),
            "criado_em": firestore.SERVER_TIMESTAMP
        }
        
        user_ref.set(user_data)
        return {"status": "sucesso", "usuario": user_data}
    except Exception as e:
        return {"status": "erro", "mensagem": f"Erro interno: {str(e)}"}

# --- ROTA DE LOGIN ---
@app.post('/login_usuario')
async def login_usuario(request: Request):
    try:
        dados = await request.json()
        telefone = str(dados.get('telefone', '')).strip()
        senha = str(dados.get('senha', ''))
        
        user_ref = db.collection('usuarios').document(telefone).get()
        
        if user_ref.exists:
            user_data = user_ref.to_dict()
            if str(user_data.get('senha')) == senha:
                return {"status": "sucesso", "usuario": user_data}
            else:
                return {"status": "erro", "mensagem": "Senha incorreta!"}
        
        return {"status": "erro", "mensagem": "Telefone não cadastrado!"}
    except Exception as e:
        return {"status": "erro", "mensagem": "Erro de conexão com o banco de dados"}

# --- ROTA MERCADO PAGO ---
@app.post('/criar_pagamento')
async def criar_pagamento(request: Request):
    try:
        dados = await request.json()
        preference_data = {
            "items": [
                {
                    "title": "Pedido KamiKami Yakissoba",
                    "quantity": 1,
                    "unit_price": float(dados.get('valor')),
                }
            ],
            "back_urls": {
                "success": "https://kamikami-delivery.web.app",
                "failure": "https://kamikami-delivery.web.app",
            },
            "auto_return": "approved",
        }
        
        result = sdk.preference().create(preference_data)
        return {"link": result["response"]["init_point"]}
    except Exception as e:
        return {"status": "erro", "mensagem": str(e)}

# Início do Servidor (Configuração específica para o Render)
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)