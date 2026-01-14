from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import mercadopago
import os
import uvicorn

app = FastAPI()

# Permite que o seu site (Frontend) acesse o Servidor (Backend)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# CREDENCIAIS DE TESTE - LUÍZ
SDK = mercadopago.SDK("TEST-819053197713657-011222-194aeab4af602ac4782b61b245651ce7-181707904")

@app.post('/checkout')
async def checkout(request: Request):
    try:
        dados = await request.json()
        itens_carrinho = dados.get('itens', [])
        frete = float(dados.get('frete', 7.0))

        # 1. Montagem Simplificada dos Itens
        itens_pagamento = []
        for item in itens_carrinho:
            itens_pagamento.append({
                "title": item['nome'],
                "quantity": 1,
                "unit_price": float(item['preco']),
                "currency_id": "BRL"
            })
        
        # 2. Adiciona o Frete como um item para não dar erro de cálculo
        itens_pagamento.append({
            "title": "Entrega KamiKami",
            "quantity": 1,
            "unit_price": frete,
            "currency_id": "BRL"
        })

        # 3. Preferência de Pagamento Básica (Mínimo exigido pelo Mercado Pago)
        preference_data = {
            "items": itens_pagamento,
            "back_urls": {
                "success": "https://kamikami-af5fe.web.app/#/sucesso",
                "failure": "https://kamikami-af5fe.web.app/#/erro",
                "pending": "https://kamikami-af5fe.web.app/#/pendente"
            },
            "auto_return": "approved",
            "payment_methods": {
                "installments": 1, # Limita a 1 vez para teste
            }
        }

        result = SDK.preference().create(preference_data)
        
        # 4. Tenta pegar o link de Sandbox, se falhar, pega o de Produção
        link = result["response"].get("sandbox_init_point") or result["response"].get("init_point")

        print(f"Link Gerado com Sucesso: {link}")
        return {"qr_code_url": link}
        
    except Exception as e:
        print(f"ERRO CRÍTICO NO BACKEND: {str(e)}")
        return {"error": str(e)}, 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)