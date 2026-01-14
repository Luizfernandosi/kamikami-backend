from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import mercadopago
import os
import uvicorn

app = FastAPI()

# Configuração de CORS para o Flutter Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# CREDENCIAIS MERCADO PAGO (SANDBOX)
SDK = mercadopago.SDK("TEST-819053197713657-011222-194aeab4af602ac4782b61b245651ce7-181707904")

# BANCO DE DADOS EM MEMÓRIA (Cardápio Inicial)
db_cardapio = {
    "frete": 7.00,
    "produtos": [
        {"id": 1, "nome": "01 - CARNE", "preco": 29.90, "emoji": "🥩", "desc": "Carne+Legumes+Verduras Tradicionais", "ativo": True},
        {"id": 2, "nome": "02 - MISTO", "preco": 28.90, "emoji": "🍱", "desc": "Carne e Frango+Legumes+Verduras", "ativo": True},
        {"id": 3, "nome": "03 - FRANGO", "preco": 27.90, "emoji": "🍗", "desc": "Frango+Legumes+Verduras Tradicionais", "ativo": True},
        {"id": 4, "nome": "04 - LEGUMES", "preco": 26.90, "emoji": "🥦", "desc": "Legumes+Verduras Tradicionais", "ativo": True},
        {"id": 5, "nome": "05 - CAMARÃO", "preco": 34.90, "emoji": "🍤", "desc": "Camarão+Legumes+Verduras Tradicionais", "ativo": True},
        {"id": 6, "nome": "06 - TEMAKI SALMÃO", "preco": 30.90, "emoji": "🍣", "desc": "Salmão Fresco, Cream Cheese e Cebolinha", "ativo": True},
        {"id": 7, "nome": "PRODUTO TESTE", "preco": 2.00, "emoji": "🛠️", "desc": "Teste de Pagamento", "ativo": True},
    ]
}

# --- ROTAS DO CARDÁPIO ---

@app.get('/cardapio')
async def obter_cardapio():
    """Retorna o cardápio atual para o site"""
    return db_cardapio

@app.post('/atualizar_cardapio')
async def atualizar_cardapio(request: Request):
    """Atualiza preços, frete e status (Área do Admin)"""
    try:
        dados = await request.json()
        
        # Validação de Senha
        if dados.get("senha") != "Kami-MAS":
            raise HTTPException(status_code=401, detail="Senha incorreta")
        
        # Atualiza os dados globais
        global db_cardapio
        db_cardapio["frete"] = float(dados["config"]["frete"])
        db_cardapio["produtos"] = dados["config"]["produtos"]
        
        print("Cardápio atualizado via Painel Administrativo")
        return {"status": "sucesso"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# --- ROTA DE PAGAMENTO ---

@app.post('/checkout')
async def checkout(request: Request):
    """Gera o link de pagamento do Mercado Pago"""
    try:
        dados = await request.json()
        itens_carrinho = dados.get('itens', [])
        frete_atual = float(dados.get('frete', db_cardapio["frete"]))
        endereco = dados.get('endereco', 'Não informado')

        itens_pagamento = []
        for item in itens_carrinho:
            itens_pagamento.append({
                "title": item['nome'],
                "quantity": 1,
                "unit_price": float(item['preco']),
                "currency_id": "BRL"
            })
        
        # Adiciona o frete como item
        itens_pagamento.append({
            "title": "Taxa de Entrega KamiKami",
            "quantity": 1,
            "unit_price": frete_atual,
            "currency_id": "BRL"
        })

        preference_data = {
            "items": itens_pagamento,
            "back_urls": {
                "success": "https://kamikami-af5fe.web.app/#/sucesso",
                "failure": "https://kamikami-af5fe.web.app/#/erro",
                "pending": "https://kamikami-af5fe.web.app/#/pendente"
            },
            "auto_return": "approved",
            "metadata": {
                "endereco_entrega": endereco
            }
        }

        result = SDK.preference().create(preference_data)
        
        # Retorna link de Sandbox (Teste) ou Produção
        link = result["response"].get("sandbox_init_point") or result["response"].get("init_point")
        
        return {"qr_code_url": link}
        
    except Exception as e:
        print(f"Erro no Checkout: {str(e)}")
        return {"error": str(e)}, 500

# --- INICIALIZAÇÃO ---

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)