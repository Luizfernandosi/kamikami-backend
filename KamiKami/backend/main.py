from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import mercadopago
import os
import uvicorn
from datetime import datetime

app = FastAPI()

# Configuração de CORS para o Flutter Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# CREDENCIAIS MERCADO PAGO
SDK = mercadopago.SDK("TEST-819053197713657-011222-194aeab4af602ac4782b61b245651ce7-181707904")

# --- BANCO DE DADOS EM MEMÓRIA ---
db_cardapio = {
    "frete": 7.00,
    "produtos": [
        {"id": 1, "nome": "01 - CARNE", "preco": 29.90, "emoji": "🥩", "desc": "Carne+Legumes+Verduras Tradicionais", "ativo": True},
        {"id": 2, "nome": "02 - MISTO", "preco": 28.90, "emoji": "🍱", "desc": "Carne e Frango+Legumes+Verduras", "ativo": True},
        {"id": 3, "nome": "03 - FRANGO", "preco": 27.90, "emoji": "🍗", "desc": "Frango+Legumes+Verduras Tradicionais", "ativo": True},
        {"id": 4, "nome": "04 - CAMARÃO", "preco": 34.90, "emoji": "🍤", "desc": "Camarão+Legumes+Verduras Tradicionais", "ativo": True},
        {"id": 5, "nome": "PRODUTO TESTE", "preco": 2.00, "emoji": "🛠️", "desc": "Teste de Pagamento", "ativo": True},
    ]
}

db_pedidos = []
db_usuarios = [] # Lista de clientes cadastrados
db_cupons = [
    {"codigo": "KAMI10", "tipo": "porcentagem", "valor": 10},
    {"codigo": "BEMVINDO5", "tipo": "fixo", "valor": 5.00}
]

# --- ROTAS DE GESTÃO (ADMIN) ---

@app.get('/cardapio')
async def obter_cardapio():
    return db_cardapio

@app.post('/atualizar_cardapio')
async def atualizar_cardapio(request: Request):
    dados = await request.json()
    if dados.get("senha") != "Kami-MAS":
        raise HTTPException(status_code=401, detail="Senha incorreta")
    global db_cardapio
    db_cardapio["frete"] = float(dados["config"]["frete"])
    db_cardapio["produtos"] = dados["config"]["produtos"]
    return {"status": "sucesso"}

@app.get('/listar_pedidos')
async def listar_pedidos():
    return db_pedidos

@app.get('/admin/clientes')
async def listar_clientes():
    """Retorna lista de clientes para o Admin"""
    return db_usuarios

@app.get('/admin/cupons')
async def listar_cupons():
    return db_cupons

@app.post('/admin/criar_cupom')
async def criar_cupom(request: Request):
    dados = await request.json()
    if dados.get("senha") == "Kami-MAS":
        db_cupons.append(dados["cupom"])
        return {"status": "sucesso"}
    return {"status": "erro"}

# --- ROTAS DO CLIENTE (LOGIN E CUPOM) ---

@app.post('/registrar_usuario')
async def registrar_usuario(request: Request):
    """Cadastra ou atualiza dados do cliente"""
    dados = await request.json()
    # Verifica se usuário já existe pelo email
    for user in db_usuarios:
        if user['email'] == dados['email']:
            user.update(dados)
            return {"status": "atualizado"}
    db_usuarios.append(dados)
    return {"status": "cadastrado"}

@app.post('/validar_cupom')
async def validar_cupom(request: Request):
    dados = await request.json()
    codigo = dados.get("codigo", "").upper()
    for c in db_cupons:
        if c["codigo"] == codigo:
            return {"status": "valido", "tipo": c["tipo"], "valor": c["valor"]}
    return {"status": "invalido"}

# --- ROTA DE CHECKOUT ---

@app.post('/checkout')
async def checkout(request: Request):
    try:
        dados = await request.json()
        itens_carrinho = dados.get('itens', [])
        frete_atual = float(dados.get('frete', db_cardapio["frete"]))
        endereco = dados.get('endereco', 'Não informado')
        email_cliente = dados.get('email', 'Visitante')
        
        # Cálculo do valor dos itens
        total_itens = sum(float(item['preco']) for item in itens_carrinho)
        
        # Registro do Pedido no Histórico
        novo_pedido = {
            "id": len(db_pedidos) + 1,
            "data": datetime.now().strftime("%d/%m/%Y"),
            "hora": datetime.now().strftime("%H:%M:%S"),
            "cliente": email_cliente,
            "itens": itens_carrinho,
            "endereco": endereco,
            "total": total_itens + frete_atual,
            "status": "Aguardando Pagamento"
        }
        db_pedidos.insert(0, novo_pedido)

        # Preparação Mercado Pago
        itens_mp = []
        for item in itens_carrinho:
            itens_mp.append({
                "title": item['nome'],
                "quantity": 1,
                "unit_price": float(item['preco']),
                "currency_id": "BRL"
            })
        
        itens_mp.append({"title": "Taxa de Entrega", "quantity": 1, "unit_price": frete_atual, "currency_id": "BRL"})

        preference_data = {
            "items": itens_mp,
            "metadata": {"id_pedido": novo_pedido["id"]},
            "back_urls": {
                "success": "https://kamikami-af5fe.web.app/#/sucesso",
                "failure": "https://kamikami-af5fe.web.app/#/erro"
            },
            "auto_return": "approved"
        }

        result = SDK.preference().create(preference_data)
        return {"qr_code_url": result["response"].get("init_point")}
        
    except Exception as e:
        return {"error": str(e)}, 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)