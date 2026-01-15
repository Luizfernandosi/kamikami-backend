import firebase_admin
from firebase_admin import credentials

cred = credentials.Certificate("kamikami-af5fe-firebase-adminsdk-fbsvc-f14d81f29a.json")
firebase_admin.initialize_app(cred)


from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import mercadopago
import os
import uvicorn
from datetime import datetime

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

SDK = mercadopago.SDK("TEST-819053197713657-011222-194aeab4af602ac4782b61b245651ce7-181707904")

# BANCO DE DADOS (Simulado - Para persistência real, use Firebase Firestore)
db_cardapio = {
    "frete": 7.00,
    "produtos": [
        {"id": 1, "nome": "01 - CARNE", "preco": 29.90, "emoji": "🥩", "desc": "Carne+Legumes+Verduras Tradicionais", "ativo": True},
        {"id": 2, "nome": "02 - MISTO", "preco": 28.90, "emoji": "🍱", "desc": "Carne e Frango+Legumes+Verduras", "ativo": True},
        {"id": 3, "nome": "03 - FRANGO", "preco": 27.90, "emoji": "🍗", "desc": "Frango+Legumes+Verduras Tradicionais", "ativo": True},
        {"id": 5, "nome": "05 - CAMARÃO", "preco": 34.90, "emoji": "🍤", "desc": "Camarão+Legumes+Verduras Tradicionais", "ativo": True},
    ]
}

db_pedidos = []
db_usuarios = [] 
db_cupons = [{"codigo": "KAMI10", "tipo": "porcentagem", "valor": 10}]

@app.get('/cardapio')
async def obter_cardapio(): return db_cardapio

@app.post('/buscar_usuario')
async def buscar_usuario(request: Request):
    dados = await request.json()
    email = dados.get("email", "").lower()
    for user in db_usuarios:
        if user['email'] == email:
            return {"status": "encontrado", "nome": user['nome'], "cep": user.get('cep', '')}
    return {"status": "nao_encontrado"}

@app.post('/registrar_usuario')
async def registrar_usuario(request: Request):
    dados = await request.json()
    db_usuarios.append(dados)
    return {"status": "sucesso"}

@app.post('/validar_cupom')
async def validar_cupom(request: Request):
    dados = await request.json()
    codigo = dados.get("codigo", "").upper()
    for c in db_cupons:
        if c["codigo"] == codigo:
            return {"status": "valido", "tipo": c["tipo"], "valor": c["valor"]}
    return {"status": "invalido"}

@app.get('/admin/clientes')
async def listar_clientes(): return db_usuarios

@app.get('/admin/cupons')
async def listar_cupons(): return db_cupons

@app.post('/admin/criar_cupom')
async def criar_cupom(request: Request):
    dados = await request.json()
    db_cupons.append(dados["cupom"])
    return {"status": "sucesso"}

@app.post('/checkout')
async def checkout(request: Request):
    dados = await request.json()
    novo_pedido = {
        "id": len(db_pedidos) + 1,
        "itens": dados['itens'],
        "endereco": dados['endereco'],
        "total": sum(i['preco'] for i in dados['itens']) + float(dados['frete']),
        "status": "Pendente"
    }
    db_pedidos.insert(0, novo_pedido)
    preference_data = {"items": [{"title": i['nome'], "quantity": 1, "unit_price": float(i['preco']), "currency_id": "BRL"} for i in dados['itens']]}
    result = SDK.preference().create(preference_data)
    return {"qr_code_url": result["response"].get("init_point")}

@app.get('/listar_pedidos')
async def listar_pedidos(): return db_pedidos

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 10000)))