from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import mercadopago
import json
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

SDK = mercadopago.SDK("TEST-819053197713657-011222-194aeab4af602ac4782b61b245651ce7-181707904")

# Caminho do arquivo que guardará os dados
DATA_FILE = "cardapio.json"

# Dados Iniciais (Caso o arquivo não exista)
dados_iniciais = {
    "frete": 7.00,
    "produtos": [
        {"id": 1, "nome": "01 - CARNE", "preco": 29.90, "emoji": "🥩", "desc": "Carne+Legumes+Verduras", "ativo": True},
        {"id": 2, "nome": "02 - MISTO", "preco": 28.90, "emoji": "🍱", "desc": "Carne e Frango+Legumes", "ativo": True}
    ]
}

def carregar_dados():
    if not os.path.exists(DATA_FILE):
        with open(DATA_FILE, "w") as f:
            json.dump(dados_iniciais, f)
    with open(DATA_FILE, "r") as f:
        return json.load(f)

def salvar_dados(dados):
    with open(DATA_FILE, "w") as f:
        json.dump(dados, f)

@app.get('/cardapio')
async def obter_cardapio():
    return carregar_dados()

@app.post('/atualizar_cardapio')
async def atualizar_cardapio(request: Request):
    dados = await request.json()
    if dados.get("senha") != "Kami-MAS":
        raise HTTPException(status_code=401, detail="Senha incorreta")
    salvar_dados(dados["config"])
    return {"status": "sucesso"}

@app.post('/checkout')
async def checkout(request: Request):
    # Lógica do Mercado Pago continua a mesma...
    dados = await request.json()
    # (Ajustar para receber os itens dinâmicos do Flutter)
    return {"qr_code_url": "link_gerado_aqui"}